//
//  EscrowError.swift
//  RunnerEscrow
//
//  Created by Peter on 09/11/2026.
//

/// Every failure mode of the goal-lock rail, typed once. Amounts and
/// goals are validated before anything reaches the network; everything
/// else is the contract or the relayer refusing.
public enum EscrowError: Sendable, Equatable, Error {

  /// Goal outside the contract bounds (1–100 km, 60 s–24 h when timed).
  case invalidGoal(String)

  /// Amount string is not base units (digits only, USDC has 6 decimals).
  case invalidAmount(String)

  /// RPC view decoded to nothing usable.
  case badResponse(String)

  /// The relayer refused the submission.
  case submitFailed(String)
}
