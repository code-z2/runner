//
//  KeychainStore.swift
//  RunnerAuth
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import Security

/// Live Keychain store. Device-only, never synced, readable only while
/// the device is unlocked. Biometrics deliberately absent: session tokens
/// must load silently on launch and in the background.
public struct KeychainStore: SecureStore, Sendable {

  private let service: String
  private let accessGroup: String?

  public init(service: String = RunnerAuth.service, accessGroup: String? = nil) {
    self.service = service
    self.accessGroup = accessGroup
  }

  private func query(forKey key: String) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
    return query
  }

  public func save(_ data: Data, forKey key: String) throws {
    var attributes = query(forKey: key)
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    let status = SecItemAdd(attributes as CFDictionary, nil)
    if status == errSecDuplicateItem {
      let update: [String: Any] = [kSecValueData as String: data]
      let updateStatus = SecItemUpdate(query(forKey: key) as CFDictionary, update as CFDictionary)
      guard updateStatus == errSecSuccess else { throw AuthError.keychain(updateStatus) }
      return
    }
    guard status == errSecSuccess else { throw AuthError.keychain(status) }
  }

  public func load(forKey key: String) throws -> Data? {
    var query = query(forKey: key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw AuthError.keychain(status) }
    return result as? Data
  }

  public func delete(forKey key: String) throws {
    let status = SecItemDelete(query(forKey: key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw AuthError.keychain(status)
    }
  }
}
