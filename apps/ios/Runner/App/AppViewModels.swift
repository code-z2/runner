//
//  AppViewModels.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import OSLog

/// Owns the app's stable UI-facing models. Each model is created only when
/// it is first needed, keeping construction out of `RootView.body`.
/// Screens bind these models; the models never reach into packages past
/// their seams.
@MainActor
final class AppViewModels {

  private static let goalLog = Logger(subsystem: "io.wades.ije", category: "GoalEvidence")

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

  lazy var live = makeLive()

  private func makeLive() -> RunLiveViewModel {
    RunLiveViewModel(
      snapshots: app.snapshots, store: { [app] in try app.runStore.get() },
      location: app.runLocation, cadence: app.runCadence, healthKit: app.healthKit,
      coach: RunCoach(),
      canTrackLocation: { [app] in
        let status = app.permissions.location.status
        return status == .whenInUse || status == .always
      },
      encounters: app.runEncounters,
      canTrackEncounters: { [app] in
        app.permissions.bluetooth.status == .ready
      },
      onFinishedRun: { [app] run, distance, splits in
        guard let service = app.goals else { return }
        do {
          try await service.recordRun(run, distanceMeters: distance, splits: splits)
        } catch {
          Self.goalLog.error(
            "Could not retain workout evidence: \(error.localizedDescription, privacy: .private)")
          return
        }
        Task { await Self.checkGoalRun(using: service) }
      })
  }

  /// Prove a saved run against the locked goal (Worker only, no chain
  /// transaction). The proof is cached for the Goals page and withdraw.
  func checkGoalRun() async {
    await Self.checkGoalRun(using: app.goals)
  }

  private static func checkGoalRun(using service: GoalService?) async {
    guard let service else { return }
    do {
      _ = try await service.checkGoalRun(service.overview())
    } catch is CancellationError {
      return
    } catch {
      goalLog.debug("Goal run check deferred: \(error.localizedDescription, privacy: .private)")
    }
  }

  lazy var run: RunViewModel = {
    RunViewModel(runs: [], loadRuns: app.loadRunHistory)
  }()
}
