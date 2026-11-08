//
//  RunRecordSnapshot.swift
//  RunnerStore
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// The cross-actor view of a recorded run. Never a model.
public struct RunRecordSnapshot: Sendable, Equatable {

  public let id: UUID

  public let startedAt: Date

  public let activeElapsed: TimeInterval

  public let distanceMeters: Double?

  public let finishReason: String

  public let batteryLevelAtStart: Float?

  public let batteryLevelAtEnd: Float?

  init(model: RunRecordModel) {
    id = model.runID
    startedAt = model.startedAt
    activeElapsed = model.activeElapsed
    distanceMeters = model.distanceMeters
    finishReason = model.finishReasonRaw
    batteryLevelAtStart = model.batteryLevelAtStart
    batteryLevelAtEnd = model.batteryLevelAtEnd
  }
}
