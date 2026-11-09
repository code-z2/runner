//
//  MemoryStore.swift
//  RunnerAuthTesting
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerAuth

/// In-memory `SecureStore`. Live Keychain behavior is proven on device;
/// logic tests run here.
public actor MemoryStore: SecureStore {

  private var values: [String: Data] = [:]

  public init() {}

  public func save(_ data: Data, forKey key: String) async throws {
    values[key] = data
  }

  public func load(forKey key: String) async throws -> Data? {
    values[key]
  }

  public func delete(forKey key: String) async throws {
    values.removeValue(forKey: key)
  }
}
