//
//  KeychainStoreTests.swift
//  RunnerAuthTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import Testing

@testable import RunnerAuth

/// Live Keychain round trip with a unique service per run. Proves the
/// SecItem path end to end; nothing here can collide with real data.
struct KeychainStoreTests {

  private func store() -> KeychainStore {
    KeychainStore(service: "app.runner.auth.test.\(UUID().uuidString)")
  }

  @Test
  func roundTripsAndDeletes() async throws {
    let store = store()
    #expect(try await store.load(forKey: "k") == nil)
    try await store.save(Data("v".utf8), forKey: "k")
    #expect(try await store.load(forKey: "k") == Data("v".utf8))
    try await store.save(Data("v2".utf8), forKey: "k")
    #expect(try await store.load(forKey: "k") == Data("v2".utf8))
    try await store.delete(forKey: "k")
    #expect(try await store.load(forKey: "k") == nil)
  }
}
