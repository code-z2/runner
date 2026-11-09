//
//  EscrowModels.swift
//  RunnerEscrow
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// USDC only. Six decimals, base-unit strings end to end — no floats
/// cross this seam.
public enum EscrowAmount {

  public static let usdcDecimals = 6

  /// `"10.50"` → `"10500000"`. Nil when the text is not a decimal or
  /// carries more precision than USDC allows.
  public static func usdc(_ major: String) -> String? {
    guard let decimal = Decimal(string: major), decimal >= 0 else { return nil }
    let scaled = decimal * Decimal(1_000_000)
    var rounded = Decimal()
    var copy = scaled
    NSDecimalRound(&rounded, &copy, 0, .plain)
    guard rounded == scaled else { return nil }
    return NSDecimalNumber(decimal: rounded).stringValue
  }
}

/// A goal locked onchain. Bounds mirror the contract exactly so invalid
/// goals fail here, before any signature or network.
public struct EscrowGoal: Sendable, Equatable, Codable {

  public static let minDistanceM: UInt32 = 1_000

  public static let maxDistanceM: UInt32 = 100_000

  public static let minSeconds: UInt32 = 60

  public static let maxSeconds: UInt32 = 86_400

  public let distanceM: UInt32

  public let maxSeconds: UInt32?

  public init(distanceM: UInt32, maxSeconds: UInt32? = nil) {
    self.distanceM = distanceM
    self.maxSeconds = maxSeconds
  }

  private enum CodingKeys: String, CodingKey {

    case distanceM = "distance_m"

    case maxSeconds = "max_seconds"
  }

  public func validated() throws {
    guard (Self.minDistanceM...Self.maxDistanceM).contains(distanceM) else {
      throw EscrowError.invalidGoal("distance_m out of 1000...100000: \(distanceM)")
    }
    if let maxSeconds {
      guard (Self.minSeconds...Self.maxSeconds).contains(maxSeconds) else {
        throw EscrowError.invalidGoal("max_seconds out of 60...86400: \(maxSeconds)")
      }
    }
  }

  /// `ft_transfer_call` memo. Sorted keys, no whitespace — the exact
  /// bytes the contract parses.
  public func memoJSON() throws -> String {
    try validated()
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return String(decoding: try encoder.encode(self), as: UTF8.self)
  }

  /// Client-side pre-check mirroring the contract's `goal_is_met`: distance
  /// covered, and average pace inside the cap when the goal is timed.
  /// Advisory only — the contract decides.
  public func meets(distanceM: UInt32, activeSeconds: UInt32) -> Bool {
    guard distanceM >= self.distanceM else { return false }
    guard let maxSeconds else { return true }
    return UInt64(activeSeconds) * UInt64(self.distanceM) <= UInt64(maxSeconds) * UInt64(distanceM)
  }
}

/// One lock, as the views return it. Amounts stay base-unit strings.
public struct EscrowLock: Sendable, Equatable, Decodable {

  public let id: UInt64

  public let ownerID: String

  public let amount: String

  public let goal: EscrowGoal

  public let createdAt: UInt64

  public init(id: UInt64, ownerID: String, amount: String, goal: EscrowGoal, createdAt: UInt64) {
    self.id = id
    self.ownerID = ownerID
    self.amount = amount
    self.goal = goal
    self.createdAt = createdAt
  }

  private enum CodingKeys: String, CodingKey {

    case id

    case ownerID = "owner_id"

    case amount

    case goal

    case createdAt = "created_at"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UInt64.self, forKey: .id)
    ownerID = try container.decode(String.self, forKey: .ownerID)
    amount = try EscrowLock.decodeU128(container, forKey: .amount)
    goal = try container.decode(EscrowGoal.self, forKey: .goal)
    createdAt = try container.decode(UInt64.self, forKey: .createdAt)
  }

  /// near `U128` serializes as a JSON string; tolerate a bare number too.
  static func decodeU128<Key: CodingKey>(_ container: KeyedDecodingContainer<Key>, forKey key: Key)
    throws
    -> String
  {
    if let string = try? container.decode(String.self, forKey: key) { return string }
    return String(try container.decode(UInt64.self, forKey: key))
  }
}

/// Contract configuration, as `get_config` returns it.
public struct EscrowConfig: Sendable, Equatable, Decodable {

  public let ownerID: String

  public let tokenID: String

  public let treasuryID: String

  public let attestorPublicKey: String

  public let minLock: String

  public let poolOwed: String

  private enum CodingKeys: String, CodingKey {

    case ownerID = "owner_id"

    case tokenID = "token_id"

    case treasuryID = "treasury_id"

    case attestorPublicKey = "attestor_public_key"

    case minLock = "min_lock"

    case poolOwed = "pool_owed"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    ownerID = try container.decode(String.self, forKey: .ownerID)
    tokenID = try container.decode(String.self, forKey: .tokenID)
    treasuryID = try container.decode(String.self, forKey: .treasuryID)
    attestorPublicKey = try container.decode(String.self, forKey: .attestorPublicKey)
    minLock = try EscrowLock.decodeU128(container, forKey: .minLock)
    poolOwed = try EscrowLock.decodeU128(container, forKey: .poolOwed)
  }
}

/// The server's run proof. Carried opaquely: the attestor signature covers
/// these exact bytes, so the app never re-encodes — parse for display only.
public struct RunProof: Sendable, Equatable, Decodable {

  public let version: Int

  public let kind: String

  public let accountID: String

  public let activityHash: String

  public let startedAt: UInt64

  public let endedAt: UInt64

  public let distanceM: UInt32

  public let activeSeconds: UInt32

  private enum CodingKeys: String, CodingKey {

    case version = "v"

    case kind

    case accountID = "account_id"

    case activityHash = "activity_hash"

    case startedAt = "started_at"

    case endedAt = "ended_at"

    case distanceM = "distance_m"

    case activeSeconds = "active_seconds"
  }
}

/// Deploy addresses. The placeholder accounts are syntactically valid but
/// nonexistent, so every call fails closed at RPC until Joel's deployment
/// values land.
public struct EscrowDeployment: Sendable, Equatable {

  public let escrow: String

  public let token: String

  public let treasury: String

  public init(escrow: String, token: String, treasury: String) {
    self.escrow = escrow
    self.token = token
    self.treasury = treasury
  }

  public static let placeholder = EscrowDeployment(
    escrow: "escrow.example.invalid",
    token: "usdc.example.invalid",
    treasury: "treasury.example.invalid"
  )
}
