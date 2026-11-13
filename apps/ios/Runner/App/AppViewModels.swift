//
//  AppViewModels.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

/// Owns the app's stable UI-facing models. Each model is created only when
/// it is first needed, keeping construction out of `RootView.body`.
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

  lazy var launch = LaunchViewModel(
    location: app.permissions.location, navigation: navigation)

  lazy var weather = WeatherModel(fetch: {
    [service = app.weatherService] in await service.currentWeather()
  })

  lazy var run: RunViewModel = {
    RunViewModel(runs: [], loadRuns: app.loadRunHistory)
  }()
}
