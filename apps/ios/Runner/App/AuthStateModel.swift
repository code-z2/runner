//
//  AuthStateModel.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Observation
import RunnerAuth

/// UI-facing auth state. Resolves the launch route from the Apple identity
/// and drives `.auth` vs `.home`. NEAR linkage never blocks the route —
/// the app works without payments.
@Observable
@MainActor
final class AuthStateModel: AppViewModelType {

  private(set) var appleUserID: String?

  private(set) var nearAccountID: String?

  private let coordinator: RunnerAuthCoordinator

  private let navigation: RootNavigation

  init(coordinator: RunnerAuthCoordinator, navigation: RootNavigation) {
    self.coordinator = coordinator
    self.navigation = navigation
  }

  /// Launch resolution: Apple identity present means a returning runner.
  func resolve() async {
    guard let account = try? await coordinator.current() else {
      navigation.route = .auth
      return
    }
    appleUserID = account.apple.userID
    nearAccountID = account.near?.account.accountID
    navigation.route = .home
  }

  /// Apple sign-in completed: persist and enter.
  func signedIn(identity: AppleIdentity) async throws {
    try await coordinator.linkApple(identity)
    appleUserID = identity.userID
    navigation.route = .home
  }

  /// Sign-out wipes the blob and returns to `.auth`.
  func signOut() async throws {
    try await coordinator.signOut()
    appleUserID = nil
    nearAccountID = nil
    navigation.route = .auth
  }
}
