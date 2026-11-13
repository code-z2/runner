//
//  SessionRecoveryTests.swift
//  RunnerSessionTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerSessionTesting
import Testing

@testable import RunnerSession

struct SessionRecoveryTests {

  @Test
  func finishedDraftKeepsExactTotalsUntilHistoryCanCommit() async throws {
    let store = InMemorySessionSnapshotStore()
    let clock = ManualClock()
    let session = WorkoutSession(
      clock: { clock.now }, wallClock: { Date(timeIntervalSince1970: clock.now) }, store: store)
    let start = Date(timeIntervalSince1970: clock.now)
    try await session.start()
    clock.advance(by: 30)
    try await session.pause(distanceMeters: 125)
    clock.advance(by: 20)
    let paused = try #require(try store.load())
    #expect(paused.pendingRun?.activeElapsed == 30)
    #expect(paused.pendingRun?.finishReason == .crashCut)
    #expect(paused.distanceMeters == 125)

    try await session.resume(distanceMeters: 125)
    clock.advance(by: 10)
    let finished = try await session.finish(distanceMeters: 150)
    let pending = try #require(try store.load())
    #expect(pending.pendingRun == finished)
    #expect(pending.pendingRun?.activeElapsed == 40)
    #expect(pending.distanceMeters == 150)
    #expect(finished.pauses == [DateInterval(start: start.addingTimeInterval(30), duration: 20)])
    #expect(finished.finishedAtWall.timeIntervalSince(start) == 60)
  }

  @Test
  func finishingWhilePausedClosesThePauseAtFinish() async throws {
    let store = InMemorySessionSnapshotStore()
    let clock = ManualClock()
    let session = WorkoutSession(
      clock: { clock.now }, wallClock: { Date(timeIntervalSince1970: clock.now) }, store: store)
    try await session.start()
    clock.advance(by: 30)
    try await session.pause()
    clock.advance(by: 15)
    let finished = try await session.finish()
    #expect(finished.activeElapsed == 30)
    #expect(finished.pauses.first?.duration == 15)
    #expect(finished.pauses.first?.end == finished.finishedAtWall)
  }

  @Test
  func interruptedRunIsCutAtSnapshotValues() throws {
    let store = InMemorySessionSnapshotStore()
    let snapshot = SessionSnapshotModel(
      id: UUID(),
      startedAtWall: Date(timeIntervalSince1970: 1_000),
      accumulatedActive: 210.0,
      state: .active,
      batteryLevelAtStart: 0.9,
      batteryLevel: 0.7,
      checkpointAtWall: Date(timeIntervalSince1970: 1_210)
    )
    try store.save(snapshot)

    let record = try WorkoutSession.recoverInterruptedRun(in: store)

    #expect(record?.activeElapsed == 210.0)
    #expect(record?.finishReason == .crashCut)
    #expect(record?.batteryLevelAtStart == 0.9)
    #expect(record?.batteryLevelAtEnd == 0.7)
  }

  @Test
  func recoveryClearsSoSecondRecoveryFindsNothing() throws {
    let store = InMemorySessionSnapshotStore()
    let snapshot = SessionSnapshotModel(
      id: UUID(),
      startedAtWall: Date(timeIntervalSince1970: 1_000),
      accumulatedActive: 210.0,
      state: .paused,
      batteryLevelAtStart: 0.9,
      batteryLevel: 0.7,
      checkpointAtWall: Date(timeIntervalSince1970: 1_210)
    )
    try store.save(snapshot)

    _ = try WorkoutSession.recoverInterruptedRun(in: store)

    #expect(try WorkoutSession.recoverInterruptedRun(in: store) == nil)
  }

  @Test
  func missingSnapshotRecoversNothing() throws {
    let store = InMemorySessionSnapshotStore()

    #expect(try WorkoutSession.recoverInterruptedRun(in: store) == nil)
  }

  @Test
  func finishedSnapshotRecoversNothing() throws {
    let store = InMemorySessionSnapshotStore()
    let snapshot = SessionSnapshotModel(
      id: UUID(),
      startedAtWall: Date(timeIntervalSince1970: 1_000),
      accumulatedActive: 210.0,
      state: .finished,
      batteryLevelAtStart: 0.9,
      batteryLevel: 0.7,
      checkpointAtWall: Date(timeIntervalSince1970: 1_210)
    )
    try store.save(snapshot)

    #expect(try WorkoutSession.recoverInterruptedRun(in: store) == nil)
  }
}
