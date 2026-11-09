//
//  SessionLifecycle.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerAuth

/// Scene-driven session hooks. `RootView` forwards phase moves here;
/// this decides what the move means. No UI, no timers — just the
/// policy, testable without a scene.
actor SessionLifecycle {

  private let coordinator: RunnerAuthCoordinator

  private let audit: AuditLog

  private let onBackground: @Sendable () async -> Void

  init(
    coordinator: RunnerAuthCoordinator,
    audit: AuditLog = AuditLog(),
    onBackground: @escaping @Sendable () async -> Void = {}
  ) {
    self.coordinator = coordinator
    self.audit = audit
    self.onBackground = onBackground
  }

  /// Maps a scene-phase move onto work. Background checkpoints the run;
  /// activation re-resolves the route.
  func moved(to phase: ScenePhaseBridge) async -> RunnerRoute? {
    switch phase {
    case .background:
      await onBackground()
      return nil
    case .active:
      return await resolveRoute()
    case .inactive:
      return nil
    }
  }

  private func resolveRoute() async -> RunnerRoute {
    guard let account = try? await coordinator.current() else { return .auth }
    audit.signedInRestored(userID: account.apple.userID)
    return .home
  }
}
