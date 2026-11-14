//
//  AppRouting.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import Observation

/// Top-level routes. `.launch` resolves the session, `.auth` collects the
/// Apple identity, `.home` is the running app. Feature routes live with
/// their features.
enum RunnerRoute: Equatable, Sendable {

  case launch

  case auth

  case home
}

/// Universal-link routes served by the associated domain. The auth
/// callback stays with `AuthCallbackHandler` — it carries a query
/// contract and a state check. These are plain navigation links with
/// no query contract: unknown hosts, wrong schemes, and any other path
/// stay in Safari.
enum AppLinkRoute: Equatable, Sendable {

  case launch

  case home

  init?(url: URL, host: String) {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
      parts.scheme == "https",
      parts.host == host
    else { return nil }
    switch parts.path {
    case "/launch": self = .launch
    case "/home": self = .home
    default: return nil
    }
  }

  var route: RunnerRoute {
    switch self {
    case .launch: .launch
    case .home: .home
    }
  }
}

/// Root-level navigation state, shared with the auth lifecycle.
@Observable
@MainActor
final class RootNavigation {

  var route: RunnerRoute = .launch

  var phase: ScenePhaseBridge = .active

  init() {}
}

enum HomeDestination: Hashable, Sendable {

  case community

  case history

  case countdown(distanceKilometers: Double?)

  case live(distanceKilometers: Double?)

  case summary(RunSummary)

  case savedSummary(RunSummary)
}

enum GoalDestination: Hashable, Sendable {
  case lock
  case funding(GoalDraft, requestID: UUID)
}

@Observable
@MainActor
final class HomeNavigation {

  var path: [HomeDestination] = []

  var goalPath: [GoalDestination] = []

  var showingPacePilot = false

  func updatePathFromNavigationStack(_ proposedPath: [HomeDestination]) {
    if case .live = path.last, proposedPath != path { return }
    path = proposedPath
  }

  func openPacePilot() {
    showingPacePilot = true
  }

  func open(_ destination: HomeDestination) {
    path.append(destination)
  }
}

/// Scene phase without importing SwiftUI into services. `RootView` maps
/// the real `ScenePhase` onto this value.
enum ScenePhaseBridge: Equatable, Sendable {

  case active

  case inactive

  case background
}
