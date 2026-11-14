import RunnerGateway
import RunnerNear
import RunnerUI
import SwiftUI

struct HomeView: View {

  let run: RunViewModel
  var live: RunLiveViewModel?
  var goalService: GoalService?
  var community = CommunityViewModel()
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
    case .countdown, .live, .summary, .communityFunding, .claimAmount, .claimDone: return true
    default: return false
    }
  }

  /// The pass signed for the run just finished, for its summary banner.
  private func claimPass(for run: RunSummary) -> ClaimPass? {
    guard let pass = community.pass, pass.runID == run.id else { return nil }
    return ClaimPass(pass)
  }

  private var poolQuote: ((Decimal, FundingNetwork, String) async throws -> IntentQuote)? {
    guard community.isAvailable else { return nil }
    return { [community] amount, network, address in
      try await community.quote(amount: amount, network: network, returnAddress: address)
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
              CommunityPage(
                balance: community.balance ?? 0, places: community.places,
                placesUnavailable: community.placesUnavailable,
                onFund: { navigation.open(.communityFunding) },
                onClaim: { navigation.open(.claimAmount($0)) }
              )
              .task { await community.refresh() }
              .refreshable { await community.refresh() }
            case .communityFunding:
              CommunityFundingPage(
                balance: community.balance ?? 0,
                requestQuote: poolQuote,
                onFunded: {
                  guard navigation.path.last == destination else { return }
                  navigation.path.removeLast()
                }, unavailable: poolQuote == nil)
            case .claimAmount(let place):
              ClaimAmountPage(
                place: place, claimable: community.claimable, balance: community.balance ?? 0
              ) { amount in
                let receipt = try await community.claim(at: place, amount: amount)
                guard navigation.path.last == destination else { return }
                navigation.path[navigation.path.count - 1] = .claimDone(receipt)
              }
            case .claimDone(let receipt):
              ClaimDonePage(receipt: receipt) {
                guard navigation.path.last == destination else { return }
                navigation.path.removeLast()
              }
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
                claimPass: destination == .summary(savedRun) ? claimPass(for: savedRun) : nil,
                communityBalanceLow: community.balanceLow,
                openClaim: { navigation.open(.community) },
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
