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

/// Scene phase without importing SwiftUI into services. `RootView` maps
/// the real `ScenePhase` onto this value.
enum ScenePhaseBridge: Equatable, Sendable {

  case active

  case inactive

  case background
}
