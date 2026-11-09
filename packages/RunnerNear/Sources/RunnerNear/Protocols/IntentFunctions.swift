//
//  IntentFunctions.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// The seam over the 1Click (NEAR Intents) client. Quotes, deposit notices,
/// and status polls cross as typed records; the api key never leaves the
/// Rust core after construction.
public protocol IntentFunctions: Sendable {

  func tokens() async throws -> [IntentToken]

  func quote(_ request: IntentQuoteRequest) async throws -> IntentQuote

  func submitDeposit(depositAddress: String, txHash: String) async throws -> IntentStatusReport

  func status(depositAddress: String) async throws -> IntentStatusReport
}

public struct IntentToken: Sendable, Equatable {
  public let assetID: String
  public let symbol: String
  public let decimals: UInt32
  public let blockchain: String
  public init(assetID: String, symbol: String, decimals: UInt32, blockchain: String) {
    self.assetID = assetID
    self.symbol = symbol
    self.decimals = decimals
    self.blockchain = blockchain
  }
}

public enum IntentStatus: Sendable, Equatable {
  case pendingDeposit
  case knownDepositTx
  case incompleteDeposit
  case processing
  case success
  case refunded
  case failed

  public var isTerminal: Bool {
    switch self {
    case .success, .refunded, .failed: return true
    default: return false
    }
  }
}

public struct IntentQuoteRequest: Sendable, Equatable {
  public let dry: Bool
  public let swapType: String
  public let slippageBps: UInt32
  public let originAsset: String
  public let depositType: String
  public let destinationAsset: String
  public let amount: String
  public let refundTo: String
  public let refundType: String
  public let recipient: String
  public let recipientType: String
  public let deadline: String
  public init(
    dry: Bool, swapType: String, slippageBps: UInt32, originAsset: String, depositType: String,
    destinationAsset: String, amount: String, refundTo: String, refundType: String,
    recipient: String, recipientType: String, deadline: String
  ) {
    self.dry = dry
    self.swapType = swapType
    self.slippageBps = slippageBps
    self.originAsset = originAsset
    self.depositType = depositType
    self.destinationAsset = destinationAsset
    self.amount = amount
    self.refundTo = refundTo
    self.refundType = refundType
    self.recipient = recipient
    self.recipientType = recipientType
    self.deadline = deadline
  }
}

public struct IntentQuote: Sendable, Equatable {
  public let depositAddress: String?
  public let amountIn: String
  public let amountOut: String
  public let minAmountOut: String
  public let deadline: String?
  public let timeEstimateSecs: Double
  public init(
    depositAddress: String?, amountIn: String, amountOut: String, minAmountOut: String,
    deadline: String?, timeEstimateSecs: Double
  ) {
    self.depositAddress = depositAddress
    self.amountIn = amountIn
    self.amountOut = amountOut
    self.minAmountOut = minAmountOut
    self.deadline = deadline
    self.timeEstimateSecs = timeEstimateSecs
  }
}

public struct IntentStatusReport: Sendable, Equatable {
  public let status: IntentStatus
  public let updatedAt: String
  public init(status: IntentStatus, updatedAt: String) {
    self.status = status
    self.updatedAt = updatedAt
  }
}
