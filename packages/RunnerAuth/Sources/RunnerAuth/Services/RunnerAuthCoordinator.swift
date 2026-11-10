//
//  RunnerAuthCoordinator.swift
//  RunnerAuth
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// Owns the runner’s identities in one atomic Keychain blob. Linking is
/// ordered — Apple first, everything else after — and sign-out wipes the
/// blob. Chain signing itself stays in RunnerNear behind `NearSigner`;
/// this box only keeps the sessions that authorize it.
public actor RunnerAuthCoordinator {

  private let store: any SecureStore
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init(store: any SecureStore) {
    self.store = store
  }

  /// A fresh Apple login replaces everything: new runner, new sessions.
  public func linkApple(_ identity: AppleIdentity) async throws {
    try await save(
      PersistedAccount(
        appleUserID: identity.userID,
        email: identity.email,
        givenName: identity.givenName,
        familyName: identity.familyName,
        appleToken: identity.identityToken,
        serverSession: nil,
        nearSubject: nil,
        nearAccountID: nil,
        nearPublicKey: nil,
        nearToken: nil
      ))
  }

  public func linkServerSession(_ token: String) async throws {
    var persisted = try await require()
    persisted.serverSession = token
    try await save(persisted)
  }

  public func linkNear(session: PasskeySession, account: NearAccount) async throws {
    var persisted = try await require()
    persisted.nearSubject = session.subject
    persisted.nearAccountID = account.accountID
    persisted.nearPublicKey = account.publicKey
    persisted.nearToken = session.idToken
    try await save(persisted)
  }

  public func current() async throws -> RunnerAccount? {
    guard let persisted = try await loaded() else { return nil }
    let apple = AppleIdentity(
      userID: persisted.appleUserID, email: persisted.email, givenName: persisted.givenName,
      familyName: persisted.familyName, identityToken: persisted.appleToken ?? "")
    let near: NearLink?
    if let subject = persisted.nearSubject,
      let accountID = persisted.nearAccountID,
      let publicKey = persisted.nearPublicKey,
      let idToken = persisted.nearToken
    {
      near = NearLink(
        idToken: idToken, subject: subject,
        account: NearAccount(accountID: accountID, publicKey: publicKey))
    } else {
      near = nil
    }
    let localAccount: NearAccount?
    if let accountID = persisted.nearLocalAccountID,
      let publicKey = persisted.nearLocalPublicKey
    {
      localAccount = NearAccount(accountID: accountID, publicKey: publicKey)
    } else {
      localAccount = nil
    }
    return RunnerAccount(
      apple: apple, serverSession: persisted.serverSession, near: near, localAccount: localAccount)
  }

  public func signOut() async throws {
    try await store.delete(forKey: RunnerAuth.accountKey)
  }

  // MARK: - Private

  private func loaded() async throws -> PersistedAccount? {
    guard let data = try await store.load(forKey: RunnerAuth.accountKey) else { return nil }
    guard let account = try? decoder.decode(PersistedAccount.self, from: data) else {
      throw AuthError.unreadableClaims
    }
    return account
  }

  private func require() async throws -> PersistedAccount {
    guard let persisted = try await loaded() else { throw AuthError.noSession }
    return persisted
  }

  private func save(_ persisted: PersistedAccount) async throws {
    try await store.save(encoder.encode(persisted), forKey: RunnerAuth.accountKey)
  }
}
