//
//  AuthStateModelTests.swift
//  RunnerTests
//
//  Created by Peter on 09/11/2026.
//

import RunnerAuth
import RunnerAuthTesting
import Testing

@testable import Runner

@MainActor
struct AuthStateModelTests {

  @Test
  func emptyStoreResolvesToAuth() async {
    let navigation = RootNavigation()
    let model = AuthStateModel(
      coordinator: RunnerAuthCoordinator(store: MemoryStore()), navigation: navigation)
    await model.resolve()
    #expect(navigation.route == .auth)
  }

  @Test
  func signedInGoesHomeAndOutReturnsToAuth() async throws {
    let navigation = RootNavigation()
    let model = AuthStateModel(
      coordinator: RunnerAuthCoordinator(store: MemoryStore()), navigation: navigation)
    try await model.signedIn(
      identity: AppleIdentity(
        userID: "u", email: nil, givenName: nil, familyName: nil, identityToken: "t"))
    #expect(navigation.route == .home)
    try await model.signOut()
    #expect(navigation.route == .auth)
  }
}
