//
//  CoordinatorTests.swift
//  RunnerAuthTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerAuthTesting
import RunnerNear
import Testing

@testable import RunnerAuth

struct CoordinatorTests {

  private func apple() -> AppleIdentity {
    AppleIdentity(
      userID: "apple-user-1", email: nil, givenName: nil, familyName: nil,
      identityToken: "apple-jwt")
  }

  private func coordinator() -> (RunnerAuthCoordinator, MemoryStore) {
    let store = MemoryStore()
    return (RunnerAuthCoordinator(store: store), store)
  }

  @Test
  func memoryStoreRoundTrips() async throws {
    let store = MemoryStore()
    #expect(try await store.load(forKey: "k") == nil)
    try await store.save(Data("v".utf8), forKey: "k")
    #expect(try await store.load(forKey: "k") == Data("v".utf8))
    try await store.delete(forKey: "k")
    #expect(try await store.load(forKey: "k") == nil)
  }

  @Test
  func appleOnlyIsAValidAccount() async throws {
    let (auth, _) = coordinator()
    #expect(try await auth.current() == nil)
    try await auth.linkApple(apple())
    let account = try await auth.current()
    #expect(account?.apple.userID == "apple-user-1")
    #expect(account?.near == nil)
    #expect(account?.serverSession == nil)
  }

  @Test
  func serverAndNearAttachOverTime() async throws {
    let (auth, _) = coordinator()
    try await auth.linkApple(apple())
    try await auth.linkServerSession("server-token")
    let session = PasskeySession(
      idToken: "jwt", refreshToken: nil,
      expiresAt: Date().addingTimeInterval(3600), subject: "auth0|abc")
    try await auth.linkNear(
      session: session, account: NearAccount(accountID: "a.near", publicKey: "k"))
    let account = try await auth.current()
    #expect(account?.serverSession == "server-token")
    #expect(account?.near?.account.accountID == "a.near")
    #expect(account?.near?.subject == "auth0|abc")
    #expect(account?.near?.idToken == "jwt")
  }

  @Test
  func linkingWithoutAppleFailsClosed() async throws {
    let (auth, _) = coordinator()
    await #expect(throws: AuthError.noSession) { try await auth.linkServerSession("server-token") }
    let session = PasskeySession(
      idToken: "jwt", refreshToken: nil,
      expiresAt: Date().addingTimeInterval(3600), subject: "auth0|abc")
    await #expect(throws: AuthError.noSession) {
      try await auth.linkNear(
        session: session, account: NearAccount(accountID: "a.near", publicKey: "k"))
    }
  }

  @Test
  func signOutClearsEverything() async throws {
    let (auth, store) = coordinator()
    try await auth.linkApple(apple())
    try await auth.linkServerSession("server-token")
    try await auth.signOut()
    #expect(try await auth.current() == nil)
    #expect(try await store.load(forKey: RunnerAuth.accountKey) == nil)
  }
}
