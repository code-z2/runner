//
//  RunStoreTests.swift
//  RunnerStoreTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerSession
import RunnerStoreTesting
import SwiftData
import Testing

@testable import RunnerStore

struct RunStoreTests {

  private func finishedRun(
    id: UUID = UUID(),
    startedAt: Date = Date(timeIntervalSince1970: 1_000),
    elapsed: TimeInterval = 60,
    distanceMeters: Double? = 2_000
  ) -> (FinishedRunModel, Double?) {
    let run = FinishedRunModel(
      id: id,
      startedAtWall: startedAt,
      activeElapsed: elapsed,
      finishedAtWall: Date(timeIntervalSince1970: 1_000 + elapsed),
      finishReason: .userFinished,
      batteryLevelAtStart: 0.9,
      batteryLevelAtEnd: 0.8
    )
    return (run, distanceMeters)
  }

  @Test
  func coachingHistoryCountsOnlyCompletedRunsStrictlyOverMinimumDistance() async throws {
    let store = try TestStoreFactory.makeStore()
    for index in 0..<11 {
      let (run, distance) = finishedRun(
        startedAt: Date(timeIntervalSince1970: Double(index)), distanceMeters: 2_501)
      _ = try await store.record(run, distanceMeters: distance)
    }
    let (atMinimum, _) = finishedRun()
    _ = try await store.record(atMinimum, distanceMeters: 2_500)
    let interrupted = FinishedRunModel(
      id: UUID(), startedAtWall: .now, activeElapsed: 60, finishedAtWall: .now,
      finishReason: .crashCut, batteryLevelAtStart: nil, batteryLevelAtEnd: nil)
    _ = try await store.record(interrupted, distanceMeters: 3_000)
    let eligible = try await store.recentCompletedRuns(longerThan: 2_500, limit: 10)
    #expect(eligible.count == 10)
    #expect(eligible.allSatisfy { $0.distanceMeters == 2_501 })
    #expect(eligible.last?.startedAt == Date(timeIntervalSince1970: 1))
  }

  @Test
  func versionOneHistoryMigratesAndNewRunsKeepCadence() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = ModelConfiguration(url: directory.appending(path: "runner.store"))
    let (oldRun, distance) = finishedRun()
    do {
      let schema = Schema(versionedSchema: RunnerStoreSchemaV1.self)
      let container = try ModelContainer(for: schema, configurations: [configuration])
      let context = ModelContext(container)
      context.insert(
        RunnerStoreSchemaV1.RunRecordModel(
          runID: oldRun.id, startedAt: oldRun.startedAtWall, activeElapsed: oldRun.activeElapsed,
          distanceMeters: distance, finishReasonRaw: "userFinished",
          batteryLevelAtStart: nil, batteryLevelAtEnd: nil, recordedAt: .now))
      try context.save()
    }
    let schema = Schema(versionedSchema: RunnerStoreSchemaV3.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: RunnerStoreMigrationPlan.self, configurations: [configuration])
    let store = RunStore(modelContainer: container)
    let existing = try await store.recentRuns()
    #expect(existing.first?.id == oldRun.id)
    #expect(existing.first?.distanceMeters == distance)
    #expect(existing.first?.cadenceStepsPerMinute == nil)
    let (newRun, newDistance) = finishedRun()
    let encounters = RunEncounterCounts(new: 3, again: 1, together: 1)
    _ = try await store.record(
      newRun, distanceMeters: newDistance, cadenceStepsPerMinute: 158, encounters: encounters)
    let saved = try await store.recentRuns()
    #expect(saved.first { $0.id == newRun.id }?.cadenceStepsPerMinute == 158)
    #expect(saved.first { $0.id == newRun.id }?.encounters == encounters)
    #expect(saved.first { $0.id == oldRun.id }?.encounters == nil)
  }

  @Test
  func versionTwoHistoryKeepsCadenceWhenEncounterFieldsAreAdded() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = ModelConfiguration(url: directory.appending(path: "runner.store"))
    let (run, distance) = finishedRun()
    do {
      let schema = Schema(versionedSchema: RunnerStoreSchemaV2.self)
      let container = try ModelContainer(for: schema, configurations: [configuration])
      let context = ModelContext(container)
      context.insert(
        RunnerStoreSchemaV2.RunRecordModel(
          runID: run.id, startedAt: run.startedAtWall, activeElapsed: run.activeElapsed,
          distanceMeters: distance, finishReasonRaw: "userFinished",
          batteryLevelAtStart: nil, batteryLevelAtEnd: nil, cadenceStepsPerMinute: 158,
          recordedAt: .now))
      try context.save()
    }
    let schema = Schema(versionedSchema: RunnerStoreSchemaV3.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: RunnerStoreMigrationPlan.self, configurations: [configuration])
    let store = RunStore(modelContainer: container)
    let saved = try #require(try await store.recentRuns().first)
    #expect(saved.id == run.id)
    #expect(saved.cadenceStepsPerMinute == 158)
    #expect(saved.encounters == nil)
  }

  @Test
  func recordPersistsAndReturnsSnapshot() async throws {
    let store = try TestStoreFactory.makeStore()
    let (run, distance) = finishedRun(elapsed: 90, distanceMeters: 3_000)

    let snapshot = try await store.record(run, distanceMeters: distance)

    #expect(snapshot.id == run.id)
    #expect(snapshot.activeElapsed == 90)
    #expect(snapshot.distanceMeters == 3_000)
    #expect(snapshot.finishReason == String(describing: FinishReason.userFinished))
  }

  @Test
  func recordingSameRunTwiceReturnsOneRecord() async throws {
    let store = try TestStoreFactory.makeStore()
    let (run, distance) = finishedRun()

    let first = try await store.record(run, distanceMeters: distance)
    let second = try await store.record(run, distanceMeters: distance)

    #expect(first == second)
    #expect(try await store.recentRuns(limit: 10).count == 1)
  }

  @Test
  func recentRunsAreNewestFirstAndCapped() async throws {
    let store = try TestStoreFactory.makeStore()
    for (index, elapsed) in [30.0, 60.0, 90.0].enumerated() {
      let startedAt = Date(timeIntervalSince1970: 1_000 + Double(index))
      let (run, distance) = finishedRun(id: UUID(), startedAt: startedAt, elapsed: elapsed)
      _ = try await store.record(run, distanceMeters: distance)
    }

    let recent = try await store.recentRuns(limit: 2)

    #expect(recent.count == 2)
    #expect(recent[0].activeElapsed == 90)
    #expect(recent[1].activeElapsed == 60)
  }

  @Test
  func personalBestsComputeFromHistory() async throws {
    let store = try TestStoreFactory.makeStore()
    let slow = finishedRun(id: UUID(), elapsed: 600, distanceMeters: 2_000)
    _ = try await store.record(slow.0, distanceMeters: slow.1)
    let fast = finishedRun(id: UUID(), elapsed: 300, distanceMeters: 2_000)
    _ = try await store.record(fast.0, distanceMeters: fast.1)
    let short = finishedRun(id: UUID(), elapsed: 60, distanceMeters: 500)
    _ = try await store.record(short.0, distanceMeters: short.1)

    let bests = try await store.personalBests()

    #expect(bests.totalRuns == 3)
    #expect(bests.totalActiveTime == 960)
    #expect(bests.longest?.activeElapsed == 600)
    #expect(bests.fastestPaceSecondsPerMeter == 0.15)
  }

  @Test
  func emptyStoreHasEmptyBests() async throws {
    let store = try TestStoreFactory.makeStore()

    let bests = try await store.personalBests()

    #expect(bests.totalRuns == 0)
    #expect(bests.totalActiveTime == 0)
    #expect(bests.longest == nil)
    #expect(bests.fastestPaceSecondsPerMeter == nil)
  }
}
