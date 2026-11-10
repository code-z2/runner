//
//  LocalKeyStoreTests.swift
//  RunnerAuthTests
//
//  Created by Peter on 10/11/2026.
//

import RunnerAuthTesting
import RunnerNearTesting
import Testing

@testable import RunnerAuth
@testable import RunnerNear

struct LocalKeyStoreTests {

  private func apple() -> AppleIdentity {
    AppleIdentity(userID: "u", email: nil, givenName: nil, familyName: nil, identityToken: "t")
  }

  private func setup() async throws -> (RunnerAuthCoordinator, LocalKeyStore, MockNearCore) {
    let memory = MemoryStore()
    let core = MockNearCore()
    let coordinator = RunnerAuthCoordinator(store: memory)
    try await coordinator.linkApple(apple())
    return (coordinator, LocalKeyStore(store: memory, core: core), core)
  }

  @Test
  func generatePersistsAndReusesTheKey() async throws {
    let (coordinator, keys, core) = try await setup()
    await core.scriptKeypair(NearKeypair(secretBase64: "c2VjcmV0", publicKey: "ed25519:abc"))
    await core.scriptAccountID("deadbeef.near")
    let first = try await keys.account()
    #expect(first.account.accountID == "deadbeef.near")
    #expect(first.secretBase64 == "c2VjcmV0")
    // Second call returns the stored key without touching the core again.
    let second = try await keys.account()
    #expect(second.account == first.account)
    #expect(try await coordinator.current()?.localAccount?.accountID == "deadbeef.near")
    #expect(try await coordinator.current()?.near == nil)
  }

  @Test
  func keyBeforeIdentityIsRefused() async {
    let keys = LocalKeyStore(store: MemoryStore(), core: MockNearCore())
    await #expect(throws: AuthError.self) {
      try await keys.account()
    }
  }

  @Test
  func wipeForgetsTheKey() async throws {
    let (_, keys, core) = try await setup()
    await core.scriptKeypair(NearKeypair(secretBase64: "c2VjcmV0", publicKey: "ed25519:abc"))
    await core.scriptAccountID("deadbeef.near")
    _ = try await keys.account()
    try await keys.wipe()
    await core.scriptKeypair(NearKeypair(secretBase64: "bmV3", publicKey: "ed25519:def"))
    await core.scriptAccountID("cafe.near")
    let rotated = try await keys.account()
    #expect(rotated.account.accountID == "cafe.near")
  }

  @Test
  func signOutWipesKeyWithIdentity() async throws {
    let (coordinator, keys, core) = try await setup()
    await core.scriptKeypair(NearKeypair(secretBase64: "c2VjcmV0", publicKey: "ed25519:abc"))
    await core.scriptAccountID("deadbeef.near")
    _ = try await keys.account()
    try await coordinator.signOut()
    await #expect(throws: AuthError.self) {
      try await keys.account()
    }
  }
}
