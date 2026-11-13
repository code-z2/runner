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

  public let cadenceStepsPerMinute: Int?

  public let encounters: RunEncounterCounts?

  init(model: RunRecordModel) {
    cadenceStepsPerMinute = model.cadenceStepsPerMinute
    id = model.runID
    startedAt = model.startedAt
    activeElapsed = model.activeElapsed
    distanceMeters = model.distanceMeters
    finishReason = model.finishReasonRaw
    batteryLevelAtStart = model.batteryLevelAtStart
    batteryLevelAtEnd = model.batteryLevelAtEnd
    if let new = model.newEncounters, let again = model.repeatEncounters,
      let together = model.togetherEncounters
    {
      encounters = RunEncounterCounts(new: new, again: again, together: together)
    } else {
      encounters = nil
    }
  }
}
