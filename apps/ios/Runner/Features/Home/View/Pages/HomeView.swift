import SwiftUI

struct HomeView: View {

  let run: RunViewModel
  let weatherModel: WeatherModel
  var date: Date = .now
  var onStart: ((Double?) -> Void)?
  @AppStorage("pacePilot.enabled")
  private var pacePilotEnabled = false

  @Bindable
  var navigation: HomeNavigation

  @State
  private var selection = HomeTab.run

  private var isWorkoutFlow: Bool {
    guard selection == .run else { return false }
    switch navigation.path.last {
    case .countdown, .live, .summary: return true
    default: return false
    }
  }

  var body: some View {
    TabView(selection: $selection) {
      Tab("Run", systemImage: "waveform.path", value: HomeTab.run) {
        NavigationStack(path: $navigation.path) {
          RunReadyView(
            viewModel: run, weather: weatherModel.weather, date: date,
            onStart: { navigation.open(.countdown(distanceKilometers: $0)) },
            open: navigation.open
          )
          .navigationDestination(for: HomeDestination.self) { destination in
            switch destination {
            case .community:
              CommunityPage()
            case .countdown(let distanceKilometers):
              RunCountdownPage(pacePilotEnabled: pacePilotEnabled) {
                guard navigation.path.last == destination else { return }
                navigation.path[navigation.path.count - 1] = .live(
                  distanceKilometers: distanceKilometers)
                onStart?(distanceKilometers)
              }
            case .live(let distanceKilometers):
              RunLivePage(
                goalKilometers: distanceKilometers, pacePilotEnabled: pacePilotEnabled,
                finish: { elapsed in
                  guard navigation.path.last == destination else { return }
                  navigation.path[navigation.path.count - 1] = .summary(elapsed: elapsed)
                })
            case .summary(let elapsed):
              RunSummaryPage(elapsed: elapsed)
            case .savedSummary(let savedRun):
              RunSummaryPage(
                elapsed: savedRun.elapsed, date: savedRun.date,
                distanceKilometers: RunHistoryMetrics.kilometers(savedRun.distanceMeters))
            case .history:
              RunHistoryPage(runs: run.runs, unavailable: run.historyUnavailable)
            }
          }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
      }
      Tab("Goals", systemImage: "target", value: HomeTab.goals) {
        ContentUnavailableView("No goals yet", systemImage: "target")
          .toolbarVisibility(.hidden, for: .tabBar)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !isWorkoutFlow {
        HomeTabBar(selection: $selection, openPacePilot: navigation.openPacePilot)
      }
    }
    .fullScreenCover(isPresented: $navigation.showingPacePilot) {
      PacePilotOptInPage(enabled: $pacePilotEnabled)
    }
  }
}
