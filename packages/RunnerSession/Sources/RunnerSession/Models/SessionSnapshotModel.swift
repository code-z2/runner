//
//  SessionSnapshotModel.swift
//  RunnerSession
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// The persisted truth about an unfinished run. Whoever reads it after a
/// crash cuts the run at exactly these values — never estimates forward.
public struct SessionSnapshotModel: Sendable, Equatable, Codable {

  public let id: UUID

  public let startedAtWall: Date

  public let accumulatedActive: TimeInterval

  public let state: SessionState

  public let batteryLevelAtStart: Float?

  public let batteryLevel: Float?

  public let checkpointAtWall: Date

  public let distanceMeters: Double?

  public let finishReason: FinishReason?

  public let pauses: [DateInterval]?

  public init(
    id: UUID,
    startedAtWall: Date,
    accumulatedActive: TimeInterval,
    state: SessionState,
    batteryLevelAtStart: Float?,
    batteryLevel: Float?,
    checkpointAtWall: Date,
    distanceMeters: Double? = nil,
    finishReason: FinishReason? = nil,
    pauses: [DateInterval]? = nil
  ) {
    self.id = id
    self.startedAtWall = startedAtWall
    self.accumulatedActive = accumulatedActive
    self.state = state
    self.batteryLevelAtStart = batteryLevelAtStart
    self.batteryLevel = batteryLevel
    self.checkpointAtWall = checkpointAtWall
    self.distanceMeters = distanceMeters
    self.finishReason = finishReason
    self.pauses = pauses
  }

  /// Read without clearing so callers can commit to history first.
  public var pendingRun: FinishedRunModel? {
    let reason: FinishReason
    switch state {
    case .active, .paused: reason = .crashCut
    case .finished:
      guard let finishReason else { return nil }
      reason = finishReason
    case .idle: return nil
    }
    return FinishedRunModel(
      id: id, startedAtWall: startedAtWall, activeElapsed: accumulatedActive,
      finishedAtWall: checkpointAtWall, finishReason: reason,
      batteryLevelAtStart: batteryLevelAtStart, batteryLevelAtEnd: batteryLevel,
      pauses: pauses ?? [])
  }
}
