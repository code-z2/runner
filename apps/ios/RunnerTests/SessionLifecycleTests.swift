//
//  SessionLifecycleTests.swift
//  RunnerTests
//
//  Created by Peter on 09/11/2026.
//

import RunnerAuth
import RunnerAuthTesting
import Testing

@testable import Runner

/// Sendable checkpoint flag — the `onBackground` hook is `@Sendable`,
/// so the test records through an actor instead of a captured var.
private actor CheckpointFlag {

  private(set) var value = false

  func set() { value = true }
}

struct SessionLifecycleTests {

  @Test
  func backgroundRunsCheckpointAndReturnsNil() async {
    let flag = CheckpointFlag()
    let lifecycle = SessionLifecycle(
      coordinator: RunnerAuthCoordinator(store: MemoryStore()),
      onBackground: { await flag.set() })
    let route = await lifecycle.moved(to: .background)
    #expect(route == nil)
    #expect(await flag.value)
  }

  @Test
  func activeWithoutSessionRoutesToAuth() async {
    let lifecycle = SessionLifecycle(
      coordinator: RunnerAuthCoordinator(store: MemoryStore()))
    #expect(await lifecycle.moved(to: .active) == .auth)
  }

  @Test
  func activeWithSessionRoutesHome() async throws {
    let coordinator = RunnerAuthCoordinator(store: MemoryStore())
    try await coordinator.linkApple(
      AppleIdentity(
        userID: "u", email: nil, givenName: nil, familyName: nil, identityToken: "t"))
    let lifecycle = SessionLifecycle(coordinator: coordinator)
    #expect(await lifecycle.moved(to: .active) == .home)
  }

  @Test
  func inactiveDoesNothing() async {
    let lifecycle = SessionLifecycle(
      coordinator: RunnerAuthCoordinator(store: MemoryStore()))
    #expect(await lifecycle.moved(to: .inactive) == nil)
  }
}
