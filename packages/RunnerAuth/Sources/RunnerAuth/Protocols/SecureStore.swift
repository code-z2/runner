//
//  SecureStore.swift
//  RunnerAuth
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// The seam over secret storage. Production is Keychain; tests use
/// `MemoryStore`. Values are opaque blobs — schemas live in the models.
public protocol SecureStore: Sendable {

  func save(_ data: Data, forKey key: String) async throws

  /// Save with a biometric gate. Keychain prompts on every read; the
  /// default ignores the flag (MemoryStore), so logic tests stay silent.
  func save(_ data: Data, forKey key: String, biometry: Bool) async throws

  func load(forKey key: String) async throws -> Data?

  func delete(forKey key: String) async throws
}

extension SecureStore {

  public func save(_ data: Data, forKey key: String, biometry: Bool) async throws {
    try await save(data, forKey: key)
  }
}
