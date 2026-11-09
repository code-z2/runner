//
//  RunnerApp.swift
//  Runner
//
//  Created by Peter on 07/11/2026.
//

import SwiftUI

/// Application entry. The composition root lives in `AppModel`; routing
/// state lives in `RootNavigation`. No UI is built here beyond the
/// launch shell — screens arrive with their features.
@main
struct RunnerApp: App {

  @State
  private var app = AppModel()

  @State
  private var navigation = RootNavigation()

  var body: some Scene {
    WindowGroup {
      RootView(app: app, navigation: navigation)
        .onOpenURL { url in
          Task {
            if app.callbacks.isAuthCallback(url) {
              do {
                try await app.flow.completeCallback(url)
              } catch {
                app.audit.ceremonyFailed(String(describing: error))
              }
              return
            }
            if let link = AppLinkRoute(url: url, host: AppConstants.associatedDomain) {
              let route = link.route
              await MainActor.run { navigation.route = route }
            }
          }
        }
        .onChange(of: navigation.phase) { _, phase in
          Task { await app.lifecycle.moved(to: phase) }
        }
    }
  }
}
