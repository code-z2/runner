//
//  AppRouting.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Observation

/// Top-level routes. `.launch` resolves the session, `.auth` collects the
/// Apple identity, `.home` is the running app. Feature routes live with
/// their features.
enum RunnerRoute: Equatable, Sendable {

  case launch

  case auth

  case home
}

/// Root-level navigation state, shared with the auth lifecycle.
@Observable
@MainActor
final class RootNavigation {

  var route: RunnerRoute = .launch

  var phase: ScenePhaseBridge = .active

  init() {}
}

/// Scene phase without importing SwiftUI into services. `RootView` maps
/// the real `ScenePhase` onto this value.
enum ScenePhaseBridge: Equatable, Sendable {

  case active

  case inactive

  case background
}
