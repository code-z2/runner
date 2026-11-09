//
//  AppDatabaseTests.swift
//  RunnerTests
//
//  Created by Peter on 09/11/2026.
//

import Testing

@testable import Runner

struct AppDatabaseTests {

  @Test
  func ephemeralContainerBuilds() throws {
    let database = try AppDatabase.ephemeral()
    #expect(!database.container.configurations.isEmpty)
  }
}
