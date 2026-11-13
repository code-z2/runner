//
//  TestStoreFactory.swift
//  RunnerStoreTesting
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import SwiftData

@testable import RunnerStore

/// Fresh in-memory store per test. Real container, no hardware, no disk.
public enum TestStoreFactory {

  public static func makeStore() throws -> RunStore {
    let schema = Schema(versionedSchema: RunnerStoreSchemaV2.self)
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: schema,
      migrationPlan: RunnerStoreMigrationPlan.self,
      configurations: [configuration]
    )
    return RunStore(modelContainer: container)
  }
}
