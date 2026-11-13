import SwiftUI

struct RootView: View {

  @Environment(\.scenePhase)
  private var scenePhase

  @State
  private var viewModels: AppViewModels

  @State
  private var homeNavigation = HomeNavigation()

  private let navigation: RootNavigation

  init(app: AppModel, navigation: RootNavigation) {
    self.navigation = navigation
    _viewModels = State(initialValue: AppViewModels(app: app, navigation: navigation))
  }

  var body: some View {
    HomeView(
      run: viewModels.run, live: viewModels.live, weatherModel: viewModels.weather,
      navigation: homeNavigation
    )
    .accessibilityHidden(navigation.route == .launch)
    .allowsHitTesting(navigation.route != .launch)
    .task(id: HomeRefresh(phase: scenePhase, route: navigation.route)) {
      if scenePhase == .background {
        await viewModels.live.checkpoint()
        return
      }
      guard scenePhase == .active, navigation.route != .launch else { return }
      do {
        try await viewModels.live.recover()
      } catch {
        // Starting a run retries recovery before it can replace the draft.
      }
      await viewModels.run.refreshHistory()
      await viewModels.weather.refresh()
    }
    .overlay {
      if navigation.route == .launch {
        LaunchPage()
          .transition(.identity)
          .task(
            id: LaunchRequest(
              phase: ScenePhaseBridge(scenePhase), status: viewModels.launch.locationStatus)
          ) {
            await viewModels.launch.resolve(phase: ScenePhaseBridge(scenePhase))
          }
      }
    }
    .preferredColorScheme(.light)
    .onChange(of: navigation.route) { _, route in
      if route == .launch, !viewModels.live.hasSession { homeNavigation.path.removeAll() }
    }
    .onChange(of: scenePhase) { _, phase in
      navigation.phase = ScenePhaseBridge(phase)
    }
  }
}

private struct HomeRefresh: Equatable {

  let phase: ScenePhase
  let route: RunnerRoute
}

private struct LaunchRequest: Equatable {

  let phase: ScenePhaseBridge
  let status: LocationPermissionService.Status
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
