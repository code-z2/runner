//
//  RunnerStoreSchema.swift
//  RunnerStore
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import SwiftData

/// Schema history starts here and is never deleted. Additive changes only.
public enum RunnerStoreSchemaV1: VersionedSchema {

  @Model
  final class RunRecordModel {

    @Attribute(.unique)
    var runID: UUID

    var startedAt: Date

    var activeElapsed: TimeInterval

    var distanceMeters: Double?

    var finishReasonRaw: String

    var batteryLevelAtStart: Float?

    var batteryLevelAtEnd: Float?

    var recordedAt: Date

    init(
      runID: UUID,
      startedAt: Date,
      activeElapsed: TimeInterval,
      distanceMeters: Double?,
      finishReasonRaw: String,
      batteryLevelAtStart: Float?,
      batteryLevelAtEnd: Float?,
      recordedAt: Date
    ) {
      self.runID = runID
      self.startedAt = startedAt
      self.activeElapsed = activeElapsed
      self.distanceMeters = distanceMeters
      self.finishReasonRaw = finishReasonRaw
      self.batteryLevelAtStart = batteryLevelAtStart
      self.batteryLevelAtEnd = batteryLevelAtEnd
      self.recordedAt = recordedAt
    }
  }

  public static let versionIdentifier = Schema.Version(1, 0, 0)

  public static var models: [any PersistentModel.Type] {
    [RunRecordModel.self]
  }
}

public enum RunnerStoreSchemaV2: VersionedSchema {

  @Model
  final class RunRecordModel {

    @Attribute(.unique)
    var runID: UUID

    var startedAt: Date

    var activeElapsed: TimeInterval

    var distanceMeters: Double?

    var finishReasonRaw: String

    var batteryLevelAtStart: Float?

    var batteryLevelAtEnd: Float?

    var recordedAt: Date

    var cadenceStepsPerMinute: Int?

    init(
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

  public static let versionIdentifier = Schema.Version(2, 0, 0)

  public static var models: [any PersistentModel.Type] {
    [RunRecordModel.self]
  }
}

public enum RunnerStoreSchemaV3: VersionedSchema {

  public static let versionIdentifier = Schema.Version(3, 0, 0)

  public static var models: [any PersistentModel.Type] {
    [RunRecordModel.self]
  }
}

public enum RunnerStoreMigrationPlan: SchemaMigrationPlan {

  public static var schemas: [any VersionedSchema.Type] {
    [RunnerStoreSchemaV1.self, RunnerStoreSchemaV2.self, RunnerStoreSchemaV3.self]
  }

  public static var stages: [MigrationStage] {
    [
      .lightweight(fromVersion: RunnerStoreSchemaV1.self, toVersion: RunnerStoreSchemaV2.self),
      .lightweight(fromVersion: RunnerStoreSchemaV2.self, toVersion: RunnerStoreSchemaV3.self),
    ]
  }
}
