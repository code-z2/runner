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

  private let batteryLevel: @Sendable () -> Float?

  private let store: any SessionSnapshotStore

  private var stateValue: SessionState = .idle

  private var runID: UUID?

  private var startedAtWall: Date?

  private var accumulatedActive: TimeInterval = 0

  private var segmentStart: TimeInterval?

  private var batteryLevelAtStart: Float?

  private var finishedRecord: FinishedRunModel?

  public init(
    clock: @Sendable @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
    batteryLevel: @Sendable @escaping () -> Float? = { nil },
    store: some SessionSnapshotStore
  ) {
    self.clock = clock
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
    runID = UUID()
    startedAtWall = Date()
    accumulatedActive = 0
    segmentStart = clock()
    batteryLevelAtStart = batteryLevel()
    finishedRecord = nil
    stateValue = .active
    try persist()
  }

  public func pause() throws {
    guard stateValue == .active else {
      throw SessionError.notActive
    }
    accumulatedActive += currentSegment()
    segmentStart = nil
    stateValue = .paused
    try persist()
  }

  public func resume() throws {
    guard stateValue == .paused else {
      throw SessionError.notPaused
    }
    segmentStart = clock()
    stateValue = .active
    try persist()
  }

  public func finish(reason: FinishReason = .userFinished) throws -> FinishedRunModel {
    if let finishedRecord {
      return finishedRecord
    }
    guard stateValue == .active || stateValue == .paused else {
      throw SessionError.nothingToFinish
    }
    accumulatedActive += currentSegment()
    segmentStart = nil
    stateValue = .finished
    let record = FinishedRunModel(
      id: runID ?? UUID(),
      startedAtWall: startedAtWall ?? Date(),
      activeElapsed: accumulatedActive,
      finishedAtWall: Date(),
      finishReason: reason,
      batteryLevelAtStart: batteryLevelAtStart,
      batteryLevelAtEnd: batteryLevel()
    )
    finishedRecord = record
    try persist()
    return record
  }

  public func checkpoint() throws {
    guard stateValue == .active || stateValue == .paused else {
      return
    }
    try persist()
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

  private func persist() throws {
    let snapshot = SessionSnapshotModel(
      id: runID ?? UUID(),
      startedAtWall: startedAtWall ?? Date(),
      accumulatedActive: activeElapsed,
      state: stateValue,
      batteryLevelAtStart: batteryLevelAtStart,
      batteryLevel: batteryLevel(),
      checkpointAtWall: Date()
    )
    try store.save(snapshot)
  }
}
