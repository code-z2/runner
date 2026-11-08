//
//  RunnerStoreSchema.swift
//  RunnerStore
//
//  Created by Peter on 07/11/2026.
//

import SwiftData

/// Schema history starts here and is never deleted. Additive changes only.
public enum RunnerStoreSchemaV1: VersionedSchema {

  public static let versionIdentifier = Schema.Version(1, 0, 0)

  public static var models: [any PersistentModel.Type] {
    [RunRecordModel.self]
  }
}

/// Migration plan. Stages grow here when V2 lands; V1 is never removed.
public enum RunnerStoreMigrationPlan: SchemaMigrationPlan {

  public static var schemas: [any VersionedSchema.Type] {
    [RunnerStoreSchemaV1.self]
  }

  public static var stages: [MigrationStage] {
    []
  }
}
