//
//  RunRecordModel.swift
//  RunnerStore
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import SwiftData

/// One recorded run. Numbers only — no route, per the product spec.
@Model
public final class RunRecordModel {

  @Attribute(.unique)
  public var runID: UUID

  public var startedAt: Date

  public var activeElapsed: TimeInterval

  public var distanceMeters: Double?

  public var finishReasonRaw: String

  public var batteryLevelAtStart: Float?

  public var batteryLevelAtEnd: Float?

  public var recordedAt: Date

  public var cadenceStepsPerMinute: Int?

  public init(
    runID: UUID,
    startedAt: Date,
    activeElapsed: TimeInterval,
    distanceMeters: Double?,
    finishReasonRaw: String,
    batteryLevelAtStart: Float?,
    batteryLevelAtEnd: Float?,
    cadenceStepsPerMinute: Int? = nil,
    recordedAt: Date
  ) {
    self.runID = runID
    self.startedAt = startedAt
    self.activeElapsed = activeElapsed
    self.distanceMeters = distanceMeters
    self.finishReasonRaw = finishReasonRaw
    self.batteryLevelAtStart = batteryLevelAtStart
    self.batteryLevelAtEnd = batteryLevelAtEnd
    self.cadenceStepsPerMinute = cadenceStepsPerMinute
    self.recordedAt = recordedAt
  }
}
