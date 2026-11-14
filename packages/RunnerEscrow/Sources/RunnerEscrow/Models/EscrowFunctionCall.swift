//
//  EscrowFunctionCall.swift
//  RunnerEscrow
//

import Foundation

/// One NEAR function call: what a submitter signs as a delegate action.
public struct EscrowFunctionCall: Sendable, Equatable {

  public let receiverID: String

  public let method: String

  /// Exact JSON args, sorted keys.
  public let argsJSON: String

  /// Attached deposit in yoctoNEAR.
  public let depositYocto: String
}

extension EscrowCall {

  /// The contract call for this intent on `deployment`. Deposits match the
  /// Worker relay policy: one yocto where the contract asserts it, else 0.
  public func functionCall(on deployment: EscrowDeployment) throws -> EscrowFunctionCall {
    switch self {
    case .lock(let amount, let goal):
      return try call(
        deployment.token, "ft_transfer_call", "1",
        ["receiver_id": deployment.escrow, "amount": amount, "msg": goal.memoJSON()])
    case .unlock(let lockID, let proofJSON, let signatureBase64):
      return try call(
        deployment.escrow, "unlock", "0",
        ["lock_id": String(lockID), "proof": proofJSON, "signature": signatureBase64])
    case .giveUp(let lockID):
      return try call(deployment.escrow, "give_up", "1", ["lock_id": String(lockID)])
    case .withdraw(let amount, let receiverID):
      var args: [String: Any] = ["amount": amount]
      if let receiverID { args["receiver_id"] = receiverID }
      return try call(deployment.escrow, "withdraw", "1", args)
    case .relock(let amount, let goal):
      return try call(
        deployment.escrow, "lock_from_balance", "1",
        [
          "amount": amount,
          "goal": try JSONSerialization.jsonObject(with: Data(goal.memoJSON().utf8)),
        ])
    }
  }

  private func call(
    _ receiver: String, _ method: String, _ deposit: String, _ args: [String: Any]
  ) throws -> EscrowFunctionCall {
    let data = try JSONSerialization.data(
      withJSONObject: args, options: [.sortedKeys, .withoutEscapingSlashes])
    return EscrowFunctionCall(
      receiverID: receiver, method: method, argsJSON: String(decoding: data, as: UTF8.self),
      depositYocto: deposit)
  }
}
