import Foundation
import RunnerEscrow
import RunnerGateway
import RunnerNear
import RunnerSession

nonisolated enum GoalServiceError: Error {
  case missingRunProof
  case invalidQuote
  /// The lock did not clear on chain in time after the unlock.
  case unlockPending
}

/// Goal escrow wiring: 1Click quotes through the shared proxy client, goal
/// state and payouts from the Worker, escrow calls through RunnerEscrow.
/// Operations run one at a time, in call order: App Attest counters must
/// reach the Worker in order. A second caller waits instead of failing.
actor GoalService {
  /// Where a withdrawal is, for the button label.
  enum WithdrawStage: Sendable {
    /// Unlocking the goal on chain with the run proof.
    case requesting
    /// Reserving the 1Click payout on the Worker.
    case reserving
    /// Relaying escrow `withdraw` to the payout account.
    case processing
  }

  /// USDC on Base, the only funding source offered today.
  static let baseUSDC = "nep141:base-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913.omft.near"

  private let account: GoalAccount
  private let gateway: any GatewayClient
  private let intents: any IntentFunctions
  private let escrow: any EscrowFunctions
  private let deployment: EscrowDeployment
  private let evidence: GoalEvidence
  private var inFlight = false
  private var waiting: [CheckedContinuation<Void, Never>] = []

  init(
    account: GoalAccount, gateway: any GatewayClient, intents: any IntentFunctions,
    escrow: any EscrowFunctions, deployment: EscrowDeployment, evidence: GoalEvidence
  ) {
    self.account = account
    self.gateway = gateway
    self.intents = intents
    self.escrow = escrow
    self.deployment = deployment
    self.evidence = evidence
  }

  func overview() async throws -> [GoalRecord] {
    await begin()
    defer { end() }
    return try await gateway.goals(account.signed(action: "list", fields: Empty()))
  }

  /// A payable quote that delivers `amount` USDC to the escrow as a lock on
  /// `goal`. Retrying with the same `goalID` returns the saved quote.
  func quote(
    goalID: UUID, goal: EscrowGoal, amount: String, returnAddress: String
  ) async throws -> IntentQuote {
    await begin()
    defer { end() }
    let quote = try await intents.quote(
      IntentQuoteRequest(
        dry: false, swapType: "EXACT_OUTPUT", slippageBps: 100,
        originAsset: Self.baseUSDC, depositType: "ORIGIN_CHAIN",
        destinationAsset: "nep141:\(deployment.token)", amount: amount,
        refundTo: returnAddress, refundType: "ORIGIN_CHAIN",
        recipient: deployment.escrow, recipientType: "DESTINATION_CHAIN",
        deadline: Date.now.addingTimeInterval(900).ISO8601Format(),
        customRecipientMsg: goal.depositMessage(owner: account.accountID, fundingID: goalID)))
    guard quote.depositAddress?.isEmpty == false, quote.deadline != nil else {
      throw GoalServiceError.invalidQuote
    }
    return quote
  }

  /// All the chain work for a goal. Each stage is one contract call and
  /// first checks the chain, so tapping Withdraw again resumes at the first
  /// unfinished stage and never repeats a finished one:
  /// 1. `unlock` with the run proof, only while the lock is still on chain
  ///    (the account is seeded first; seeding is idempotent).
  /// 2. Reserve the payout on the Worker (returns the same reservation).
  /// 3. `withdraw`, only while the escrow still holds the amount.
  func withdraw(
    goalID: UUID, progress: @escaping @Sendable (WithdrawStage) async -> Void = { _ in }
  ) async throws {
    await begin()
    defer { end() }
    await progress(.requesting)
    let accountID = try await account.accountID
    guard
      let goal = try await gateway.goals(account.signed(action: "list", fields: Empty()))
        .first(where: { $0.id == goalID }),
      goal.state == "locked" || goal.state == "ready_to_withdraw"
    else { return }

    if let lockID = UInt64(goal.lockID),
      try await escrow.locks(of: accountID).contains(where: { $0.id == lockID })
    {
      guard let proof = try await evidence.proof(for: goalID) else {
        throw GoalServiceError.missingRunProof
      }
      _ = try await escrow.unlock(
        lockID: lockID, proofJSON: proof.json, signatureBase64: proof.signature)
      try await evidence.didUnlock(goalID)
    }

    await progress(.reserving)
    let payout = try await reservePayout(goalID)
    let balance = UInt64(try await escrow.balance(of: accountID)) ?? 0
    guard let amount = UInt64(payout.amount), balance >= amount else { return }
    await progress(.processing)
    _ = try await escrow.withdraw(amount: payout.amount, receiverID: payout.receiverID)
  }

  /// The Worker reads the chain at finality, so a fresh unlock can take a
  /// few seconds to show; keep asking briefly.
  private func reservePayout(_ goalID: UUID) async throws -> GoalPayout {
    for _ in 0..<10 {
      do {
        return try await gateway.withdrawGoal(
          account.signed(
            action: "withdraw", fields: GoalFields(goalID: goalID.uuidString.lowercased())))
      } catch GatewayError.server(409, let code)
        where code == "goal_locked" || code == "escrow_balance_unavailable"
      {
        try await Task.sleep(for: .seconds(2))
      }
    }
    throw GoalServiceError.unlockPending
  }

  /// The server-signed run proof for `activity`.
  func attest(_ activity: GoalRunEvidence) async throws -> GoalRunProof {
    await begin()
    defer { end() }
    let pass = try await gateway.claimPass(
      account.signed(action: nil, fields: ActivityFields(activity: activity)))
    guard let json = pass.runProof, let signature = pass.runProofSignature else {
      throw GoalServiceError.missingRunProof
    }
    return GoalRunProof(json: json, signature: signature)
  }

  func recordRun(_ run: FinishedRunModel, distanceMeters: Double?, splits: [Double]) async throws {
    try await evidence.recordRun(run, distanceMeters: distanceMeters, splits: splits)
  }

  /// Prove a saved run against the locked goal in `records`. No chain
  /// transaction: the unlock happens on withdraw. Nil while a check runs.
  func checkGoalRun(_ records: [GoalRecord]) async throws -> GoalUnlockOutcome? {
    try await evidence.check(goal: records.first { $0.state == "locked" }, using: self)
  }

  private func begin() async {
    guard inFlight else {
      inFlight = true
      return
    }
    await withCheckedContinuation { waiting.append($0) }
  }

  /// Hand the turn straight to the next waiter, or free it.
  private func end() {
    if waiting.isEmpty {
      inFlight = false
    } else {
      waiting.removeFirst().resume()
    }
  }

  private struct Empty: Encodable {}
  private struct GoalFields: Encodable { let goalID: String }
  private struct ActivityFields: Encodable { let activity: GoalRunEvidence }
}
