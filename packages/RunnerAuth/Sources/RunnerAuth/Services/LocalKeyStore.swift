//
//  LocalKeyStore.swift
//  RunnerAuth
//
//  Created by Peter on 10/11/2026.
//

import Foundation
import RunnerNear

/// Device-key lifecycle. The seed lives in its own Keychain item behind
/// the biometric gate — every read prompts — while the public key and
/// account ID stay silent in the account blob. Generates on first use;
/// requires an Apple identity already linked, so a key can never outlive
/// the runner it belongs to.
public struct LocalKeyStore: Sendable {

  private let store: any SecureStore

  private let core: any NearCoreFunctions

  private let encoder = JSONEncoder()

  private let decoder = JSONDecoder()

  public init(store: any SecureStore, core: any NearCoreFunctions) {
    self.store = store
    self.core = core
  }

  /// The device account and its seed. Generates and persists on first
  /// use; later calls return the same key. Pre-gate secrets stored in
  /// the blob migrate into the gated item on first touch.
  public func account() async throws -> (account: NearAccount, secretBase64: String) {
    if let secret = try await store.load(forKey: RunnerAuth.localKey),
      let persisted = try await loaded(),
      let publicKey = persisted.nearLocalPublicKey,
      let accountID = persisted.nearLocalAccountID
    {
      return (NearAccount(accountID: accountID, publicKey: publicKey), secret.base64EncodedString())
    }
    if var persisted = try await loaded(), let secret = persisted.nearLocalSecret,
      let publicKey = persisted.nearLocalPublicKey
    {
      try await store.save(
        Data(base64Encoded: secret) ?? Data(), forKey: RunnerAuth.localKey, biometry: true)
      let accountID = try core.implicitAccountID(publicKey: publicKey)
      persisted.nearLocalSecret = nil
      persisted.nearLocalAccountID = accountID
      try await save(persisted)
      return (NearAccount(accountID: accountID, publicKey: publicKey), secret)
    }
    var persisted = try await required()
    let keypair = try core.ed25519Keypair()
    guard let secret = Data(base64Encoded: keypair.secretBase64) else {
      throw AuthError.unreadableClaims
    }
    let accountID = try core.implicitAccountID(publicKey: keypair.publicKey)
    try await store.save(secret, forKey: RunnerAuth.localKey, biometry: true)
    persisted.nearLocalSecret = nil
    persisted.nearLocalPublicKey = keypair.publicKey
    persisted.nearLocalAccountID = accountID
    try await save(persisted)
    return (NearAccount(accountID: accountID, publicKey: keypair.publicKey), keypair.secretBase64)
  }

  /// Forgets the device key. Identity stays; the next `account()` call
  /// generates fresh.
  public func wipe() async throws {
    try await store.delete(forKey: RunnerAuth.localKey)
    guard var persisted = try await loaded() else { return }
    persisted.nearLocalSecret = nil
    persisted.nearLocalPublicKey = nil
    persisted.nearLocalAccountID = nil
    try await save(persisted)
  }

  // MARK: - Private

  private func loaded() async throws -> PersistedAccount? {
    guard let data = try await store.load(forKey: RunnerAuth.accountKey) else { return nil }
    guard let account = try? decoder.decode(PersistedAccount.self, from: data) else {
      throw AuthError.unreadableClaims
    }
    return account
  }

  private func required() async throws -> PersistedAccount {
    guard let persisted = try await loaded() else { throw AuthError.noSession }
    return persisted
  }

  private func save(_ persisted: PersistedAccount) async throws {
    try await store.save(encoder.encode(persisted), forKey: RunnerAuth.accountKey)
  }
}
