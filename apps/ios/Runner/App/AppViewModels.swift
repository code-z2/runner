//
//  AppViewModels.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

/// Owns the app's stable UI-facing models. Each model is created only when
/// its route first needs it, keeping construction out of `RootView.body`.
/// Screens bind these models; the models never reach into packages past
/// their seams.
@MainActor
final class AppViewModels {

  private let navigation: RootNavigation

  private let app: AppModel

  init(app: AppModel, navigation: RootNavigation) {
    self.app = app
    self.navigation = navigation
  }

  lazy var authState: AuthStateModel = {
    AuthStateModel(coordinator: app.auth, navigation: navigation)
  }()
}
