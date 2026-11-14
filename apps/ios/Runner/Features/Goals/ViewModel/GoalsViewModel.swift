import Foundation
import OSLog
import Observation
import RunnerGateway

@MainActor
@Observable
final class GoalsViewModel: AppViewModelType {
  enum Availability: Equatable {
    case loading
    case ready
    case unavailable
  }

  enum WithdrawalError: Equatable {
    case unavailable
    case statusUnconfirmed
  }

  private(set) var overview = GoalOverview()
  private(set) var availability: Availability = .loading
  private(set) var withdrawing: UUID?
  /// The current withdraw stage, while `withdrawing` is set.
  private(set) var withdrawStage: GoalService.WithdrawStage?
  private(set) var withdrawalError: WithdrawalError?
  /// Why the locked goal can't be withdrawn yet, from the last refresh.
  private(set) var unlockNote: String?
  /// The locked goal a server-proven run beats: withdraw unlocks it first.
  @ObservationIgnored private var provenGoal: UUID?

  @ObservationIgnored private var refreshGeneration = 0

  private static let log = Logger(subsystem: "io.wades.ije", category: "Goals")

  var canStartFunding: Bool { availability == .ready && overview.canLockGoal }

  /// Server truth: a funded goal appears here once its escrow lock exists.
  /// A saved run that beats the locked goal is proven with the Worker here
  /// (no chain transaction), so the goal shows as ready to withdraw.
  func refresh(using service: GoalService?) async {
    refreshGeneration += 1
    let generation = refreshGeneration
    guard let service else {
      availability = .unavailable
      return
    }
    if availability != .ready { availability = .loading }
    let records: [GoalRecord]
    do {
      records = try await service.overview()
    } catch {
      // The newest refresh decides, even if its task was cancelled, so the
      // page never stays on the skeleton.
      guard generation == refreshGeneration else { return }
      Self.log.error("Goals list failed: \(String(describing: error), privacy: .public)")
      availability = .unavailable
      return
    }
    do {
      if let outcome = try await service.checkGoalRun(records) {
        unlockNote = outcome.note
        if case .proven(let goalID) = outcome { provenGoal = goalID } else { provenGoal = nil }
      }
    } catch {
      Self.log.error("Goal run check failed: \(String(describing: error), privacy: .public)")
      unlockNote = "Couldn’t check your run. Pull to refresh to try again."
    }
    guard generation == refreshGeneration else { return }
    overview = GoalOverview(records: records, provenGoal: provenGoal)
    availability = .ready
  }

  func withdraw(_ goal: GoalOverview.UnlockedGoal, using service: GoalService?) async {
    guard let service, availability == .ready, withdrawing == nil,
      overview.unlocked.contains(where: { $0.id == goal.id && $0.canWithdraw })
    else { return }
    withdrawing = goal.id
    withdrawStage = .requesting
    defer {
      withdrawing = nil
      withdrawStage = nil
    }
    do {
      try await service.withdraw(goalID: goal.id) { [weak self] stage in
        await MainActor.run { self?.withdrawStage = stage }
      }
    } catch let GatewayError.server(status, _) where status == 503 {
      withdrawalError = .unavailable
    } catch {
      withdrawalError = .statusUnconfirmed
    }
    await refresh(using: service)
  }

  func dismissWithdrawalError() { withdrawalError = nil }

  /// Button text for the goal being withdrawn.
  var withdrawLabel: String {
    switch withdrawStage {
    case .requesting, nil: "Requesting withdrawal…"
    case .reserving: "Reserving payout…"
    case .processing: "Processing deposit…"
    }
  }

  /// A payout 1Click is still delivering: refresh until it lands.
  var isDelivering: Bool { overview.unlocked.contains { $0.isWithdrawing } }
}

extension GoalOverview {
  /// `provenGoal` is a locked goal a verified run beats: it is shown as
  /// ready to withdraw, and withdrawing unlocks it on chain first.
  init(records: [GoalRecord], provenGoal: UUID? = nil) {
    self.init()
    for record in records {
      guard let goal = record.goalDraft else { continue }
      switch record.state {
      case "locked" where record.id == provenGoal:
        unlocked.append(
          UnlockedGoal(
            id: record.id, goal: goal, returnChain: record.displayNetwork,
            returnAddress: record.returnAddress))
      case "locked":
        if active == nil {
          active = goal
          lockedAt = Date(timeIntervalSince1970: TimeInterval(record.lockedAt))
        }
      case "ready_to_withdraw", "withdrawing":
        unlocked.append(
          UnlockedGoal(
            id: record.id, goal: goal, returnChain: record.displayNetwork,
            returnAddress: record.returnAddress, isWithdrawing: record.state == "withdrawing"))
      default:
        continue
      }
    }
  }
}

extension GoalRecord {
  fileprivate var displayNetwork: String {
    originAsset.hasPrefix("nep141:base-") ? "Base" : originAsset
  }

  /// The goal with the amount that actually landed in the escrow.
  fileprivate var goalDraft: GoalDraft? {
    guard distanceM > 0, let units = Decimal(string: amount), units > 0 else { return nil }
    return GoalDraft(
      distance: .init(value: Double(distanceM) / 1_000, unit: .kilometers),
      maxSeconds: maxSeconds, amount: units / 1_000_000)
  }
}

extension GoalOverview {
  /// The best run on this device since the active goal locked, and how
  /// close it came. `note` explains a pending unlock.
  func withAttempts(_ runs: [RunSummary], note: String?) -> GoalOverview {
    guard let goal = active, let lockedAt else { return self }
    var overview = self
    let best =
      runs
      .filter { $0.date >= lockedAt }
      .compactMap { run in
        run.distanceMeters.map { (run, goal.progress(meters: $0, seconds: run.elapsed)) }
      }
      .max { $0.1 < $1.1 }
    if let (run, progress) = best, let meters = run.distanceMeters {
      overview.progress = progress
      let distance = (meters / 1_000).formatted(.number.precision(.fractionLength(2)))
      let time = Duration.seconds(run.elapsed).formatted(.time(pattern: .minuteSecond))
      overview.bestAttempt = "Best try: \(distance) km in \(time)"
    }
    if let note {
      overview.bestAttempt = [overview.bestAttempt, note].compactMap { $0 }.joined(separator: "\n")
    }
    return overview
  }
}
