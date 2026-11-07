//
//  FinishedRunModel.swift
//  RunnerSession
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// One completed run, however it ended. Totals are frozen at finish time.
public struct FinishedRunModel: Sendable, Equatable {

  public let id: UUID

  public let startedAtWall: Date

  public let activeElapsed: TimeInterval

  public let finishedAtWall: Date

  public let finishReason: FinishReason

  public let batteryLevelAtStart: Float?

  public let batteryLevelAtEnd: Float?

  public init(
    id: UUID,
    startedAtWall: Date,
    activeElapsed: TimeInterval,
    finishedAtWall: Date,
    finishReason: FinishReason,
    batteryLevelAtStart: Float?,
    batteryLevelAtEnd: Float?
  ) {
    self.id = id
    self.startedAtWall = startedAtWall
    self.activeElapsed = activeElapsed
    self.finishedAtWall = finishedAtWall
    self.finishReason = finishReason
    self.batteryLevelAtStart = batteryLevelAtStart
    self.batteryLevelAtEnd = batteryLevelAtEnd
  }
}
