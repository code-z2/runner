import RunnerUI
import SwiftUI

struct HomeView: View {

  let run: RunViewModel
  var live: RunLiveViewModel?
  var goalService: GoalService?
  let weatherModel: WeatherModel
  var date: Date = .now
  @AppStorage("pacePilot.enabled")
  private var pacePilotEnabled = false

  @Bindable
  var navigation: HomeNavigation

  @State
  private var selection = HomeTab.run

  @State
  private var goals = GoalsViewModel()

  private var hidesTabBar: Bool {
    if selection == .goals { return !navigation.goalPath.isEmpty }
    switch navigation.path.last {
    case .countdown, .live, .summary: return true
    default: return false
    }
  }

  var body: some View {
    TabView(selection: $selection) {
      Tab("Run", systemImage: "waveform.path", value: HomeTab.run) {
        NavigationStack(
          path: Binding(
            get: { navigation.path },
            set: navigation.updatePathFromNavigationStack
          )
        ) {
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
              RunCountdownPage(pacePilotEnabled: pacePilotEnabled, coach: live?.coach) {
                guard navigation.path.last == destination else { return }
                navigation.path[navigation.path.count - 1] = .live(
                  distanceKilometers: distanceKilometers)
              }
            case .live(let distanceKilometers):
              RunLivePage(
                goalKilometers: distanceKilometers, pacePilotEnabled: pacePilotEnabled,
                model: live,
                onStartFailure: {
                  guard navigation.path.last == destination else { return }
                  navigation.path.removeLast()
                },
                onFinish: { savedRun in
                  guard navigation.path.last == destination else { return }
                  navigation.path[navigation.path.count - 1] = .summary(savedRun)
                  await run.refreshHistory()
                })
            case .summary(let savedRun), .savedSummary(let savedRun):
              RunSummaryPage(
                elapsed: savedRun.elapsed, date: savedRun.date,
                distanceKilometers: RunHistoryMetrics.kilometers(savedRun.distanceMeters),
                cadence: savedRun.cadenceStepsPerMinute,
                encounters: savedRun.encounters, splits: savedRun.splits,
                healthConnection: live, showsLatestHealthExport: destination == .summary(savedRun))
            case .history:
              RunHistoryPage(runs: run.runs, unavailable: run.historyUnavailable)
            }
          }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
      }
      Tab("Goals", systemImage: "target", value: HomeTab.goals) {
        GoalsNavigation(
          model: goals, service: goalService, runs: run.runs, path: $navigation.goalPath
        )
        .toolbarVisibility(.hidden, for: .tabBar)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !hidesTabBar {
        VStack(spacing: 0) {
          if selection == .goals && goals.canStartFunding {
            Button("Lock a goal") { navigation.goalPath.append(.lock) }
              .buttonStyle(.pill())
              .padding(.horizontal, Theme.Spacing.screenInset)
              .padding(.vertical, Theme.Spacing.sm)
          }
          HomeTabBar(selection: $selection, openPacePilot: navigation.openPacePilot)
        }
      }
    }
    .fullScreenCover(isPresented: $navigation.showingPacePilot) {
      PacePilotOptInPage(enabled: $pacePilotEnabled)
    }
  }
}
