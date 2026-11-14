import Foundation
import RunnerGateway
import RunnerNear

struct CommunityPlace: Identifiable, Hashable, Sendable {
  /// The Worker's location id; one merchant account can have several.
  let id: String
  let name: String
  let account: String
  let distanceMeters: Double

  var distance: String {
    Measurement(value: distanceMeters, unit: UnitLength.meters)
      .formatted(.measurement(width: .abbreviated, usage: .road))
  }
}

/// A paid claim, for the receipt.
struct ClaimReceipt: Hashable, Sendable {
  let place: CommunityPlace
  let amount: Decimal
  let paidAt: Date
  let passLabel: String
  let transactionHash: String

  var shortHash: String {
    transactionHash.count <= 10
      ? transactionHash : "\(transactionHash.prefix(4))…\(transactionHash.suffix(4))"
  }
}

extension RunPass {
  /// "Morning run · 5.12 km"
  var label: String {
    let start = Date(timeIntervalSince1970: TimeInterval(startedAt))
    let part =
      switch Calendar.current.component(.hour, from: start) {
      case 5..<12: String(localized: "Morning run")
      case 12..<17: String(localized: "Afternoon run")
      case 17..<21: String(localized: "Evening run")
      default: String(localized: "Night run")
      }
    let km = (Double(distanceM) / 1_000).formatted(.number.precision(.fractionLength(2)))
    return "\(part) · \(km) km"
  }
}

enum CommunityPreviewData {
  static let balance: Decimal = 4_820
  static let claimable: Decimal = 2.56
  static let places = [
    CommunityPlace(id: "1", name: "Mama Put", account: "mamaput.near", distanceMeters: 350),
    CommunityPlace(id: "2", name: "Bole Corner", account: "bolecorner.near", distanceMeters: 600),
    CommunityPlace(id: "3", name: "Kofi Lab", account: "kofilab.near", distanceMeters: 1_100),
  ]
  static let receipt = ClaimReceipt(
    place: places[0], amount: 2, paidAt: .now, passLabel: "Morning run · 5.12 km",
    transactionHash: "8fK2a7Dq1xq9Lm")
}

extension ClaimPass {
  /// The summary banner's view of a run pass.
  init(_ pass: RunPass) {
    self.init(
      version: 1, accountID: "", activityHash: "", maxAmountCents: pass.maxAmountCents,
      expiresAt: pass.expiresAt, nonce: pass.nonce, signature: pass.signature,
      attestation: pass.attestation)
  }
}

/// Deposit details from a payable pool quote.
struct PoolDeposit: Identifiable, Sendable {
  let id = UUID()
  let network: FundingNetwork
  let amount: String
  let address: String
  let memo: String?
  let deadline: Date

  init?(quote: IntentQuote, network: FundingNetwork) {
    guard let address = quote.depositAddress, !address.isEmpty,
      let units = Decimal(string: quote.amountIn), units > 0,
      let timestamp = quote.deadline,
      let deadline = (try? Date(timestamp, strategy: .iso8601))
        ?? (try? Date(
          timestamp, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    else { return nil }
    var scaled = units
    var whole = Decimal()
    guard
      NSDecimalMultiplyByPowerOf10(&whole, &scaled, Int16(-network.decimals), .plain) == .noError
    else { return nil }
    self.network = network
    self.amount = whole.formatted(.number.precision(.fractionLength(0...6)))
    self.address = address
    self.memo = quote.depositMemo
    self.deadline = deadline
  }
}
