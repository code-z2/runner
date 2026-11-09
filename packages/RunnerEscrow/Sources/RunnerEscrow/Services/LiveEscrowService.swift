//
//  LiveEscrowService.swift
//  RunnerEscrow
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// Live goal-lock rail: views over RPC, intents through the relayer seam.
/// Goals and amounts are validated before anything reaches the network;
/// the contract remains the source of truth for everything else.
public struct LiveEscrowService: EscrowFunctions, Sendable {

  private let rpc: any NearRpcFunctions

  private let submitter: any EscrowSubmitter

  private let deployment: EscrowDeployment

  public init(
    rpc: any NearRpcFunctions, submitter: any EscrowSubmitter,
    deployment: EscrowDeployment = .placeholder
  ) {
    self.rpc = rpc
    self.submitter = submitter
    self.deployment = deployment
  }

  // MARK: - Intents

  public func lock(amount: String, goal: EscrowGoal) async throws -> EscrowReceipt {
    try requireAmount(amount)
    try goal.validated()
    return try await submitter.submit(.lock(amount: amount, goal: goal))
  }

  public func unlock(lockID: UInt64, proofJSON: String, signatureBase64: String) async throws
    -> EscrowReceipt
  {
    guard !proofJSON.isEmpty, !signatureBase64.isEmpty else {
      throw EscrowError.badResponse("unlock needs the server proof and signature")
    }
    return try await submitter.submit(
      .unlock(lockID: lockID, proofJSON: proofJSON, signatureBase64: signatureBase64))
  }

  public func giveUp(lockID: UInt64) async throws -> EscrowReceipt {
    try await submitter.submit(.giveUp(lockID: lockID))
  }

  public func withdraw(amount: String, receiverID: String?) async throws -> EscrowReceipt {
    try requireAmount(amount)
    return try await submitter.submit(.withdraw(amount: amount, receiverID: receiverID))
  }

  public func relock(amount: String, goal: EscrowGoal) async throws -> EscrowReceipt {
    try requireAmount(amount)
    try goal.validated()
    return try await submitter.submit(.relock(amount: amount, goal: goal))
  }

  // MARK: - Views

  public func locks(of accountID: String) async throws -> [EscrowLock] {
    let data = try await rpc.viewCall(
      contractID: deployment.escrow, method: "get_locks",
      argsJSON: #"{"account_id":"\#(accountID)"}"#)
    do {
      return try JSONDecoder().decode([EscrowLock].self, from: data)
    } catch {
      throw EscrowError.badResponse("get_locks undecodable: \(error)")
    }
  }

  public func balance(of accountID: String) async throws -> String {
    let data = try await rpc.viewCall(
      contractID: deployment.escrow, method: "get_balance",
      argsJSON: #"{"account_id":"\#(accountID)"}"#)
    do {
      return try JSONDecoder().decode(String.self, from: data)
    } catch {
      throw EscrowError.badResponse("get_balance undecodable: \(error)")
    }
  }

  public func config() async throws -> EscrowConfig {
    let data = try await rpc.viewCall(
      contractID: deployment.escrow, method: "get_config", argsJSON: "{}")
    do {
      return try JSONDecoder().decode(EscrowConfig.self, from: data)
    } catch {
      throw EscrowError.badResponse("get_config undecodable: \(error)")
    }
  }

  // MARK: - Private

  /// Base-unit strings only: digits, nonzero. USDC precision is enforced
  /// at the edge by `EscrowAmount.usdc`, never re-checked here.
  private func requireAmount(_ amount: String) throws {
    guard !amount.isEmpty, amount.allSatisfy(\.isNumber),
      amount != String(repeating: "0", count: amount.count)
    else {
      throw EscrowError.invalidAmount(amount)
    }
  }
}
