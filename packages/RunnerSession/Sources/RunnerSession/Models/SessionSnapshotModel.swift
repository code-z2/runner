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

  public init(
    id: UUID,
    startedAtWall: Date,
    accumulatedActive: TimeInterval,
    state: SessionState,
    batteryLevelAtStart: Float?,
    batteryLevel: Float?,
    checkpointAtWall: Date
  ) {
    self.id = id
    self.startedAtWall = startedAtWall
    self.accumulatedActive = accumulatedActive
    self.state = state
    self.batteryLevelAtStart = batteryLevelAtStart
    self.batteryLevel = batteryLevel
    self.checkpointAtWall = checkpointAtWall
  }
}
