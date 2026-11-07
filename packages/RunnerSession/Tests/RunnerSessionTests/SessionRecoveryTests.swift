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
