//
//  WorkoutSessionTests.swift
//  RunnerSessionTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerSessionTesting
import Testing

@testable import RunnerSession

struct WorkoutSessionTests {

  private func makeSession(
    clock: ManualClock = ManualClock(),
    battery: Float? = 0.8
  ) -> (WorkoutSession, ManualClock) {
    let session = WorkoutSession(
      clock: { clock.now },
      batteryLevel: { battery },
      store: InMemorySessionSnapshotStore()
    )
    return (session, clock)
  }

  @Test
  func startMovesIdleToActiveWithZeroElapsed() async throws {
    let (session, _) = makeSession()

    try await session.start()

    #expect(await session.state == .active)
    #expect(await session.activeElapsed == 0)
  }

  @Test
  func activeTimeAccumulatesOnMonotonicClock() async throws {
    let (session, clock) = makeSession()

    try await session.start()
    clock.advance(by: 60)

    #expect(await session.activeElapsed == 60)
  }

  @Test
  func pauseFreezesElapsed() async throws {
    let (session, clock) = makeSession()

    try await session.start()
    clock.advance(by: 30)
    try await session.pause()
    clock.advance(by: 120)

    #expect(await session.state == .paused)
    #expect(await session.activeElapsed == 30)
  }

  @Test
  func resumeContinuesFromFrozenValue() async throws {
    let (session, clock) = makeSession()

    try await session.start()
    clock.advance(by: 30)
    try await session.pause()
    clock.advance(by: 120)
    try await session.resume()
    clock.advance(by: 10)

    #expect(await session.activeElapsed == 40)
  }

  @Test
  func finishReturnsRecordAndFreezes() async throws {
    let (session, clock) = makeSession(battery: 0.9)

    try await session.start()
    clock.advance(by: 45)
    let record = try await session.finish()

    #expect(await session.state == .finished)
    #expect(record.activeElapsed == 45)
    #expect(record.finishReason == .userFinished)
    #expect(record.batteryLevelAtStart == 0.9)
    #expect(record.batteryLevelAtEnd == 0.9)
  }

  @Test
  func secondFinishReturnsSameRecord() async throws {
    let (session, clock) = makeSession()

    try await session.start()
    clock.advance(by: 45)
    let first = try await session.finish()
    clock.advance(by: 100)
    let second = try await session.finish()

    #expect(first == second)
  }

  @Test
  func startWhileActiveThrows() async throws {
    let (session, _) = makeSession()

    try await session.start()

    await #expect(throws: SessionError.alreadyActive) {
      try await session.start()
    }
  }

  @Test
  func pauseWhileIdleThrows() async throws {
    let (session, _) = makeSession()

    await #expect(throws: SessionError.notActive) {
      try await session.pause()
    }
  }

  @Test
  func resumeWhileActiveThrows() async throws {
    let (session, _) = makeSession()

    try await session.start()

    await #expect(throws: SessionError.notPaused) {
      try await session.resume()
    }
  }

  @Test
  func finishWhileIdleThrows() async throws {
    let (session, _) = makeSession()

    await #expect(throws: SessionError.nothingToFinish) {
      try await session.finish()
    }
  }

  @Test
  func checkpointPersistsCurrentTotals() async throws {
    let store = InMemorySessionSnapshotStore()
    let clock = ManualClock()
    let session = WorkoutSession(
      clock: { clock.now },
      batteryLevel: { 0.5 },
      store: store
    )

    try await session.start()
    clock.advance(by: 25)
    try await session.checkpoint()

    let snapshot = try store.load()
    #expect(snapshot?.accumulatedActive == 25)
    #expect(snapshot?.state == .active)
    #expect(snapshot?.batteryLevel == 0.5)
  }
}
