import CoreLocation
import Foundation
import RunnerEscrow
import RunnerGateway
import RunnerNear

nonisolated enum CommunityServiceError: Error, Equatable {
  case invalidAmount
  case invalidQuote
  /// The pass was spent, or expired, before this claim.
  case passUsed
  /// The DAO refused the payout; the pass was released and can be used again.
  case notAccepted
  /// The payout is a DAO proposal the council must approve; the pass is spent.
  case awaitingCouncil
  /// The relay ran the call and it failed (e.g. not a registered merchant).
  case failed(transaction: String)
}

/// Community wiring: the pool is the DAO's USDC balance, places come from
/// the Worker by coarse geohash cell, claims spend a run's claim pass at
/// the treasury, and gifts reach the DAO through a 1Click quote. Shares
/// the runner's account and its request turn with Goals.
actor CommunityService {
  private let goals: GoalService
  private let account: GoalAccount
  private let gateway: any GatewayClient
  private let intents: any IntentFunctions
  private let rpc: any NearRpcFunctions
  private let evidence: GoalEvidence
  private let deployment: EscrowDeployment
  private let dao: String

  init(
    goals: GoalService, account: GoalAccount, gateway: any GatewayClient,
    intents: any IntentFunctions, rpc: any NearRpcFunctions, evidence: GoalEvidence,
    deployment: EscrowDeployment, dao: String
  ) {
    self.goals = goals
    self.account = account
    self.gateway = gateway
    self.intents = intents
    self.rpc = rpc
    self.evidence = evidence
    self.deployment = deployment
    self.dao = dao
  }

  /// USDC the DAO holds for claims.
  func poolBalance() async throws -> Decimal {
    let data = try await rpc.viewCall(
      contractID: deployment.token, method: "ft_balance_of",
      argsJSON: #"{"account_id":"\#(dao)"}"#)
    guard let units = Decimal(string: try JSONDecoder().decode(String.self, from: data)) else {
      throw CommunityServiceError.invalidAmount
    }
    return units / 1_000_000
  }

  /// Approved places around the runner, nearest first. Nil without a
  /// location fix.
  func nearbyPlaces() async throws -> [CommunityPlace]? {
    guard let location = await Self.currentLocation() else { return nil }
    return try await places(near: location)
  }

  /// Approved places in the runner's geohash cell and the eight around it,
  /// nearest first. Only the cells leave the device.
  func places(near location: CLLocation) async throws -> [CommunityPlace] {
    let merchants = try await gateway.merchants(
      cells: Geohash.cellAndNeighbors(of: location.coordinate))
    return
      merchants
      .map { merchant in
        CommunityPlace(
          id: merchant.id, name: merchant.name, account: merchant.nearAccount,
          distanceMeters: location.distance(
            from: CLLocation(latitude: merchant.latitude, longitude: merchant.longitude)))
      }
      .sorted { $0.distanceMeters < $1.distanceMeters }
  }

  /// The newest claim pass the treasury has not spent.
  func openPass() async throws -> RunPass? {
    while let pass = try await evidence.openPass() {
      guard try await isSpent(pass) else { return pass }
      try await evidence.markClaimed(nonce: pass.nonce)
    }
    return nil
  }

  /// Spend `pass` at `place`. Paid only when the treasury logs the payout
  /// approval; a released pass stays usable.
  func claim(_ pass: RunPass, at place: CommunityPlace, amount: Decimal) async throws
    -> ClaimReceipt
  {
    var cents = amount * 100
    var rounded = Decimal()
    NSDecimalRound(&rounded, &cents, 0, .down)
    guard let value = UInt32(exactly: NSDecimalNumber(decimal: rounded).intValue), value > 0,
      Int(value) <= pass.maxAmountCents
    else { throw CommunityServiceError.invalidAmount }
    guard pass.isOpen(), try await !isSpent(pass) else {
      try await evidence.markClaimed(nonce: pass.nonce)
      throw CommunityServiceError.passUsed
    }

    let call = try EscrowFunctionCall.claim(
      attestation: pass.attestation, signatureBase64: pass.signature,
      merchantID: place.account, amountCents: value, on: deployment)
    let result = try await goals.exclusive { [account] in try await account.relay(call) }
    guard result.status == .succeeded else {
      throw CommunityServiceError.failed(transaction: result.transactionHash)
    }
    let logs = result.logs.filter { $0.hasPrefix("claim \(pass.nonce) ") }
    if logs.contains(where: { $0.contains(" approved as DAO proposal ") }) {
      try await evidence.markClaimed(nonce: pass.nonce)
      return ClaimReceipt(
        place: place, amount: Decimal(value) / 100, paidAt: .now,
        passLabel: pass.label, transactionHash: result.transactionHash)
    }
    if logs.contains(where: { $0.contains(" released") }) {
      throw CommunityServiceError.notAccepted
    }
    try await evidence.markClaimed(nonce: pass.nonce)
    throw CommunityServiceError.awaitingCouncil
  }

  /// A payable quote that delivers exactly `amount` USDC to the pool from
  /// USDC on `network`. Refunds return to `returnAddress` on that chain.
  func quote(amount: Decimal, network: FundingNetwork, returnAddress: String) async throws
    -> IntentQuote
  {
    var usd = amount
    var atomic = Decimal()
    guard amount > 0, NSDecimalMultiplyByPowerOf10(&atomic, &usd, 6, .plain) == .noError else {
      throw CommunityServiceError.invalidAmount
    }
    let request = IntentQuoteRequest(
      dry: false, swapType: "EXACT_OUTPUT", slippageBps: 100,
      originAsset: network.assetID, depositType: "ORIGIN_CHAIN",
      destinationAsset: "nep141:\(deployment.token)",
      amount: NSDecimalNumber(decimal: atomic).stringValue,
      refundTo: returnAddress, refundType: "ORIGIN_CHAIN",
      recipient: dao, recipientType: "DESTINATION_CHAIN",
      deadline: Date.now.addingTimeInterval(900).ISO8601Format())
    let quote = try await goals.exclusive { [intents] in try await intents.quote(request) }
    guard quote.depositAddress?.isEmpty == false, quote.deadline != nil else {
      throw CommunityServiceError.invalidQuote
    }
    return quote
  }

  /// One fix, or nil after 5 seconds or without permission.
  private static func currentLocation() async -> CLLocation? {
    await withTaskGroup(of: CLLocation?.self) { group in
      group.addTask {
        do {
          for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationDeniedGlobally { return nil }
            if let location = update.location { return location }
          }
        } catch {}
        return nil
      }
      group.addTask {
        try? await Task.sleep(for: .seconds(5))
        return nil
      }
      let location = await group.next() ?? nil
      group.cancelAll()
      return location
    }
  }

  private func isSpent(_ pass: RunPass) async throws -> Bool {
    let data = try await rpc.viewCall(
      contractID: deployment.treasury, method: "is_nonce_used",
      argsJSON: #"{"nonce":"\#(pass.nonce)"}"#)
    return try JSONDecoder().decode(Bool.self, from: data)
  }
}

/// Geohash cells, matching the Worker's `geohash.ts` (precision 5).
nonisolated enum Geohash {
  private static let alphabet = Array("0123456789bcdefghjkmnpqrstuvwxyz")

  static func encode(_ coordinate: CLLocationCoordinate2D, precision: Int = 5) -> String {
    var latitude = (-90.0, 90.0)
    var longitude = (-180.0, 180.0)
    var output = ""
    var bits = 0
    var index = 0
    var useLongitude = true
    while output.count < precision {
      let value = useLongitude ? coordinate.longitude : coordinate.latitude
      var range = useLongitude ? longitude : latitude
      let mid = (range.0 + range.1) / 2
      if value >= mid {
        index = (index << 1) | 1
        range.0 = mid
      } else {
        index <<= 1
        range.1 = mid
      }
      if useLongitude { longitude = range } else { latitude = range }
      useLongitude.toggle()
      bits += 1
      if bits == 5 {
        output.append(alphabet[index])
        bits = 0
        index = 0
      }
    }
    return output
  }

  /// The cell holding `coordinate` and its eight neighbours (precision 5:
  /// 13 longitude bits and 12 latitude bits per cell).
  static func cellAndNeighbors(of coordinate: CLLocationCoordinate2D) -> [String] {
    let height = 180.0 / 4_096
    let width = 360.0 / 8_192
    var cells: [String] = []
    for dLat in [0.0, -1, 1] {
      for dLng in [0.0, -1, 1] {
        let latitude = min(max(coordinate.latitude + dLat * height, -90), 90)
        var longitude = coordinate.longitude + dLng * width
        if longitude >= 180 { longitude -= 360 }
        if longitude < -180 { longitude += 360 }
        let cell = encode(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        if !cells.contains(cell) { cells.append(cell) }
      }
    }
    return cells
  }
}
