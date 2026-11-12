//
//  RootView.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import SwiftUI

/// App root. Resolves the session on launch, then renders the route.
/// Screens arrive with their features; every route is an empty shell
/// until then — no UI is built here.
struct RootView: View {

  @Environment(\.scenePhase)
  private var scenePhase

  private let app: AppModel

  private let navigation: RootNavigation

  @State
  private var models: AppViewModels

  init(app: AppModel, navigation: RootNavigation) {
    self.app = app
    self.navigation = navigation
    _models = State(wrappedValue: AppViewModels(app: app, navigation: navigation))
  }

  var body: some View {
    ZStack {
#if DEBUG
      StagingDriverView(app: app)
#else
      switch navigation.route {
      case .launch:
        EmptyView()
      case .auth:
        EmptyView()
      case .home:
        EmptyView()
      }
#endif
    }
    .task {
      await models.authState.resolve()
    }
    .onChange(of: scenePhase) { _, newPhase in
      navigation.phase = ScenePhaseBridge(newPhase)
    }
  }
}

extension ScenePhaseBridge {

  fileprivate init(_ phase: ScenePhase) {
    switch phase {
    case .active: self = .active
    case .inactive: self = .inactive
    case .background: self = .background
    @unknown default: self = .inactive
    }
  }
}
