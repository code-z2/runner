//
//  LocalKeyStore.swift
//  RunnerAuth
//
//  Created by Peter on 10/11/2026.
//

import Foundation
import RunnerNear

/// Device-key lifecycle over the same atomic blob as the identities.
/// Generates the Ed25519 key on first use, persists the seed in the
/// Keychain blob, and derives the implicit account. Requires an Apple
/// identity already linked — key before identity is refused, so a key
/// can never outlive the runner it belongs to.
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
  /// use; later calls return the same key.
  public func account() async throws -> (account: NearAccount, secretBase64: String) {
    if let persisted = try await loaded(),
      let secret = persisted.nearLocalSecret,
      let publicKey = persisted.nearLocalPublicKey
    {
      let accountID = try core.implicitAccountID(publicKey: publicKey)
      return (NearAccount(accountID: accountID, publicKey: publicKey), secret)
    }
    var persisted = try await required()
    let keypair = try core.ed25519Keypair()
    let accountID = try core.implicitAccountID(publicKey: keypair.publicKey)
    persisted.nearLocalSecret = keypair.secretBase64
    persisted.nearLocalPublicKey = keypair.publicKey
    persisted.nearLocalAccountID = accountID
    try await save(persisted)
    return (NearAccount(accountID: accountID, publicKey: keypair.publicKey), keypair.secretBase64)
  }

  /// Forgets the device key. Identity stays; the next `account()` call
  /// generates fresh.
  public func wipe() async throws {
    guard var persisted = try await loaded() else { return }
    persisted.nearLocalSecret = nil
    persisted.nearLocalPublicKey = nil
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
