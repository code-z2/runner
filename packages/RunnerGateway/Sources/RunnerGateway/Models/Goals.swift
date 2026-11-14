import Foundation

/// A locked goal as the Worker reconciles it from the escrow.
/// `state`: `locked`, `ready_to_withdraw`, `withdrawing`, `withdrawn`.
public struct GoalRecord: Sendable, Equatable, Decodable {
  public let id: UUID
  public let state: String
  public let distanceM: UInt32
  public let maxSeconds: UInt32?
  /// USDC base units that landed in the escrow lock.
  public let amount: String
  /// The 1Click asset the goal was funded from; withdrawals return to it.
  public let originAsset: String
  public let returnAddress: String
  public let lockID: String
  /// Lock creation, unix seconds rounded up.
  public let lockedAt: Int

  public init(
    id: UUID, state: String, distanceM: UInt32, maxSeconds: UInt32?, amount: String,
    originAsset: String, returnAddress: String, lockID: String, lockedAt: Int
  ) {
    self.id = id
    self.state = state
    self.distanceM = distanceM
    self.maxSeconds = maxSeconds
    self.amount = amount
    self.originAsset = originAsset
    self.returnAddress = returnAddress
    self.lockID = lockID
    self.lockedAt = lockedAt
  }

  private enum CodingKeys: String, CodingKey {
    case id, state, amount
    case distanceM = "distance_m"
    case maxSeconds = "max_seconds"
    case originAsset = "origin_asset"
    case returnAddress = "return_address"
    case lockID = "lock_id"
    case lockedAt = "locked_at"
  }
}

/// The reserved payout: the escrow `withdraw` the runner signs.
public struct GoalPayout: Sendable, Equatable, Decodable {
  public let receiverID: String
  public let amount: String

  private enum CodingKeys: String, CodingKey {
    case receiverID = "receiver_id"
    case amount
  }
}
