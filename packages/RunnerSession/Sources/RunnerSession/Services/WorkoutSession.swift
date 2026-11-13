//
//  WorkoutSession.swift
//  RunnerSession
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// The workout state machine: idle → active ⇄ paused → finished.
///
/// Time is accumulated active segments on an injected monotonic clock, so
/// sleep and wall-clock shifts can never inflate a run. Every transition and
/// checkpoint writes a snapshot; a crash cuts the run at the last one.
/// Finish is idempotent: repeating it returns the same record.
public actor WorkoutSession {

  private let clock: @Sendable () -> TimeInterval
  private let wallClock: @Sendable () -> Date

  private let batteryLevel: @Sendable () -> Float?

  private let store: any SessionSnapshotStore

  private var stateValue: SessionState = .idle

  private var runID: UUID?

  private var startedAtWall: Date?

  private var accumulatedActive: TimeInterval = 0

  private var segmentStart: TimeInterval?

  private var batteryLevelAtStart: Float?

  private var finishedRecord: FinishedRunModel?
  private var pausedAt: Date?
  private var pauses: [DateInterval] = []

  public init(
    clock: @Sendable @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
    wallClock: @Sendable @escaping () -> Date = { Date() },
    batteryLevel: @Sendable @escaping () -> Float? = { nil },
    store: some SessionSnapshotStore
  ) {
    self.clock = clock
    self.wallClock = wallClock
    self.batteryLevel = batteryLevel
    self.store = store
  }

  public var state: SessionState {
    stateValue
  }

  public var activeElapsed: TimeInterval {
    accumulatedActive + currentSegment()
  }

  public func start() throws {
    guard stateValue == .idle else {
      throw SessionError.alreadyActive
    }
    let id = UUID()
    let startedAt = wallClock()
    let battery = batteryLevel()
    try store.save(
      SessionSnapshotModel(
        id: id, startedAtWall: startedAt, accumulatedActive: 0, state: .active,
        batteryLevelAtStart: battery, batteryLevel: battery, checkpointAtWall: startedAt))
    runID = id
    startedAtWall = startedAt
    segmentStart = clock()
    batteryLevelAtStart = battery
    stateValue = .active
  }

  public func pause(distanceMeters: Double? = nil) throws {
    guard stateValue == .active else {
      throw SessionError.notActive
    }
    let elapsed = activeElapsed
    let snapshot = try persist(state: .paused, elapsed: elapsed, distanceMeters: distanceMeters)
    pausedAt = snapshot.checkpointAtWall
    accumulatedActive = elapsed
    segmentStart = nil
    stateValue = .paused
  }

  public func resume(distanceMeters: Double? = nil) throws {
    guard stateValue == .paused else {
      throw SessionError.notPaused
    }
    let snapshot = try persist(
      state: .active, elapsed: accumulatedActive, distanceMeters: distanceMeters)
    if let pause = pauseEnding(at: snapshot.checkpointAtWall) {
      pauses.append(pause)
    }
    pausedAt = nil
    segmentStart = clock()
    stateValue = .active
  }

  public func finish(
    reason: FinishReason = .userFinished, distanceMeters: Double? = nil
  ) throws -> FinishedRunModel {
    if let finishedRecord {
      return finishedRecord
    }
    guard stateValue == .active || stateValue == .paused else {
      throw SessionError.nothingToFinish
    }
    let snapshot = try persist(
      state: .finished, elapsed: activeElapsed, distanceMeters: distanceMeters, finishReason: reason
    )
    guard let record = snapshot.pendingRun else { throw SessionError.nothingToFinish }
    accumulatedActive = record.activeElapsed
    segmentStart = nil
    stateValue = .finished
    finishedRecord = record
    return record
  }

  public func checkpoint(distanceMeters: Double? = nil) throws {
    guard stateValue == .active || stateValue == .paused else {
      return
    }
    try persist(state: stateValue, elapsed: activeElapsed, distanceMeters: distanceMeters)
  }

  /// Cuts an unfinished run at its last snapshot. Returns `nil` when there
  /// is nothing to cut, and clears the store so recovery runs once.
  public static func recoverInterruptedRun(in store: some SessionSnapshotStore) throws
    -> FinishedRunModel?
  {
    guard let snapshot = try store.load() else {
      return nil
    }
    guard snapshot.state == .active || snapshot.state == .paused else {
      return nil
    }
    try store.clear()
    return FinishedRunModel(
      id: snapshot.id,
      startedAtWall: snapshot.startedAtWall,
      activeElapsed: snapshot.accumulatedActive,
      finishedAtWall: Date(),
      finishReason: .crashCut,
      batteryLevelAtStart: snapshot.batteryLevelAtStart,
      batteryLevelAtEnd: snapshot.batteryLevel
    )
  }

  private func currentSegment() -> TimeInterval {
    guard stateValue == .active, let segmentStart else {
      return 0
    }
    return clock() - segmentStart
  }

  private func pauseEnding(at end: Date) -> DateInterval? {
    guard let pausedAt, pausedAt < end else { return nil }
    return DateInterval(start: pausedAt, end: end)
  }

  @discardableResult
  private func persist(
    state: SessionState, elapsed: TimeInterval, distanceMeters: Double?,
    finishReason: FinishReason? = nil
  ) throws -> SessionSnapshotModel {
    guard let runID, let startedAtWall else { throw SessionError.notActive }
    let checkpoint = wallClock()
    let pauseIntervals = pauses + (pauseEnding(at: checkpoint).map { [$0] } ?? [])
    let snapshot = SessionSnapshotModel(
      id: runID,
      startedAtWall: startedAtWall,
      accumulatedActive: elapsed,
      state: state,
      batteryLevelAtStart: batteryLevelAtStart,
      batteryLevel: batteryLevel(),
      checkpointAtWall: checkpoint,
      distanceMeters: distanceMeters,
      finishReason: finishReason,
      pauses: pauseIntervals
    )
    try store.save(snapshot)
    return snapshot
  }
}
