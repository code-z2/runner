import Foundation
import RunnerNear

struct GoalDraft: Hashable, Sendable {
  var distance: Measurement<UnitLength>
  var maxSeconds: UInt32?
  var amount: Decimal

  init(
    distance: Measurement<UnitLength> = .init(value: 10, unit: .kilometers),
    minutes: Int = 55,
    amount: Decimal = 25
  ) {
    self.init(distance: distance, maxSeconds: UInt32(minutes * 60), amount: amount)
  }

  init(distance: Measurement<UnitLength>, maxSeconds: UInt32?, amount: Decimal) {
    self.distance = distance
    self.maxSeconds = maxSeconds
    self.amount = amount
  }

  var minutes: Int {
    get { Int(maxSeconds ?? 0) / 60 }
    set { maxSeconds = UInt32(newValue * 60) }
  }

  var distanceLabel: String {
    let value = distance.value.formatted(.number.precision(.fractionLength(0...2)))
    return "\(value) \(distance.unit.symbol)"
  }

  var timeLabel: String {
    let seconds = Int64(maxSeconds ?? 0)
    return Duration.seconds(seconds).formatted(
      .time(pattern: seconds >= 3_600 ? .hourMinuteSecond : .minuteSecond))
  }

  var amountLabel: String { amount.formatted(.currency(code: "USD")) }

  /// How close a run came: distance covered, then the time limit scaled
  /// to that distance. 1 means the goal is met.
  func progress(meters: Double, seconds: TimeInterval) -> Double {
    let goalMeters = distance.converted(to: .meters).value
    guard goalMeters > 0, meters > 0 else { return 0 }
    let covered = min(meters / goalMeters, 1)
    guard covered == 1, let maxSeconds, seconds > 0 else { return covered }
    return min(Double(maxSeconds) * meters / goalMeters / seconds, 1)
  }

  var targetLabel: String {
    guard maxSeconds != nil else { return distanceLabel }
    return "\(distanceLabel) under \(timeLabel)"
  }
}

struct GoalOverview: Sendable {
  struct Deposit: Identifiable, Hashable, Sendable {
    let id: UUID
    let goal: GoalDraft
    let amount: String
    let asset: String
    let network: String
    let address: String
    let memo: String?
    let deadline: Date

    func isPayable(at date: Date = .now) -> Bool { deadline > date }
  }

  struct PendingGoal: Sendable {
    let goal: GoalDraft
    let deposit: Deposit?
  }

  struct UnlockedGoal: Identifiable, Hashable, Sendable {
    let id: UUID
    let goal: GoalDraft
    let returnChain: String
    let returnAddress: String
    var isWithdrawing = false

    var canWithdraw: Bool { !isWithdrawing }
  }

  var pending: PendingGoal?
  var active: GoalDraft?
  /// When the active goal's escrow lock was created; runs before it don't count.
  var lockedAt: Date?
  var bestAttempt: String?
  var progress: Double = 0
  var unlocked: [UnlockedGoal] = []

  var canLockGoal: Bool { pending == nil && active == nil }
}

extension GoalOverview.Deposit {
  /// Deposit details from a payable USDC-on-Base goal quote.
  init?(id: UUID, goal: GoalDraft, quote: IntentQuote) {
    guard let address = quote.depositAddress, !address.isEmpty,
      let units = Decimal(string: quote.amountIn), units > 0,
      let timestamp = quote.deadline,
      let deadline = (try? Date(timestamp, strategy: .iso8601))
        ?? (try? Date(
          timestamp, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    else { return nil }
    self.init(
      id: id, goal: goal,
      amount: (units / 1_000_000).formatted(.number.precision(.fractionLength(0...6))),
      asset: "USDC", network: "Base", address: address, memo: quote.depositMemo,
      deadline: deadline)
  }
}
