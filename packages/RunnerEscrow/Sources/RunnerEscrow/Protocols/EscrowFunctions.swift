//
//  EscrowFunctions.swift
//  RunnerEscrow
//
//  Created by Peter on 09/11/2026.
//

/// Every state-changing escrow call, as one value. The relayer endpoint
/// shape is the backend's; this enum carries the contract-level intent so
/// the HTTP binding lands later without touching callers.
public enum EscrowCall: Sendable, Equatable {

  /// `ft_transfer_call` on the USDC contract: `msg` is the goal memo.
  case lock(amount: String, goal: EscrowGoal)

  /// `unlock`: proof bytes pass through exactly as the server sent them —
  /// the attestor signature covers those bytes.
  case unlock(lockID: UInt64, proofJSON: String, signatureBase64: String)

  /// `give_up`: explicit forfeit, 50/50 by the contract.
  case giveUp(lockID: UInt64)

  /// `withdraw` unlocked money out of the escrow.
  case withdraw(amount: String, receiverID: String?)

  /// `lock_from_balance`: re-lock unlocked money on a new goal.
  case relock(amount: String, goal: EscrowGoal)
}

/// Opaque relayer receipt. The reference is the backend's, for support
/// trails — confirmation comes from the views, never from this string.
public struct EscrowReceipt: Sendable, Equatable {

  public let reference: String

  public init(reference: String) {
    self.reference = reference
  }
}

/// Relayer submission seam. The app's submitter signs
/// `call.functionCall(on:)` as a delegate action and sends it through the
/// Worker relay.
public protocol EscrowSubmitter: Sendable {

  func submit(_ call: EscrowCall) async throws -> EscrowReceipt
}

/// The goal-lock rail both the app and tests program against.
public protocol EscrowFunctions: Sendable {

  // MARK: - Intents (relayer-submitted)

  /// Lock USDC on a goal. Returns the relayer receipt; the lock itself is
  /// confirmed through `locks(of:)`.
  func lock(amount: String, goal: EscrowGoal) async throws -> EscrowReceipt

  /// Unlock with the server's run proof. Amounts are confirmed through
  /// `balance(of:)` — the receipt only proves the relayer accepted it.
  func unlock(lockID: UInt64, proofJSON: String, signatureBase64: String) async throws
    -> EscrowReceipt

  /// Explicit forfeit. The 50/50 split happens onchain; confirm through
  /// `balance(of:)`.
  func giveUp(lockID: UInt64) async throws -> EscrowReceipt

  /// Move unlocked money out. Returns the relayer receipt.
  func withdraw(amount: String, receiverID: String?) async throws -> EscrowReceipt

  /// Re-lock unlocked money on a new goal.
  func relock(amount: String, goal: EscrowGoal) async throws -> EscrowReceipt

  // MARK: - Views (RPC)

  func locks(of accountID: String) async throws -> [EscrowLock]

  func balance(of accountID: String) async throws -> String

  func config() async throws -> EscrowConfig
}
