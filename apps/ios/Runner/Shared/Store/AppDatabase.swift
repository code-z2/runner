//
//  AppDatabase.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerStore
import SwiftData

/// The app's SwiftData container. Runs on the V1 schema with the
/// migration plan; the store file lives in the app group so the Watch
/// app shares history later. Device-only — no CloudKit, ever.
struct AppDatabase: Sendable {

  static let groupIdentifier = "group.io.wades.ije"

  let container: ModelContainer

  /// In-memory container for tests and previews. Never ships data.
  static func ephemeral() throws -> AppDatabase {
    let schema = Schema(versionedSchema: RunnerStoreSchemaV1.self)
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: schema,
      migrationPlan: RunnerStoreMigrationPlan.self,
      configurations: [configuration])
    return AppDatabase(container: container)
  }

  /// Live container in the shared app-group directory. Fails closed
  /// when the group container is missing to avoid forking run history.
  static func live() throws -> AppDatabase {
    guard
      let directory = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: groupIdentifier)
    else { throw AppDatabaseError.noAppGroupContainer }
    let configuration = ModelConfiguration(url: directory.appending(path: "runner.store"))
    let schema = Schema(versionedSchema: RunnerStoreSchemaV1.self)
    let container = try ModelContainer(
      for: schema,
      migrationPlan: RunnerStoreMigrationPlan.self,
      configurations: [configuration])
    return AppDatabase(container: container)
  }
}

enum AppDatabaseError: Error {

  case noAppGroupContainer
}
