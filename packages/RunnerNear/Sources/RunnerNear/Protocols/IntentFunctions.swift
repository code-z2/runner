//
//  IntentFunctions.swift
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// The 1Click (NEAR Intents) quote seam. Requests are built and responses
/// decoded by the Rust SDK codecs; transport is the Worker proxy, which
/// holds the partner key.
public protocol IntentFunctions: Sendable {

  func quote(_ request: IntentQuoteRequest) async throws -> IntentQuote
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
  /// `msg` of the `ft_transfer_call` that delivers to `recipient`.
  public let customRecipientMsg: String?

  public init(
    dry: Bool, swapType: String, slippageBps: UInt32, originAsset: String, depositType: String,
    destinationAsset: String, amount: String, refundTo: String, refundType: String,
    recipient: String, recipientType: String, deadline: String, customRecipientMsg: String? = nil
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
    self.customRecipientMsg = customRecipientMsg
  }
}

public struct IntentQuote: Sendable, Equatable {
  public let depositAddress: String?
  public let depositMemo: String?
  public let amountIn: String
  public let amountOut: String
  public let minAmountOut: String
  public let deadline: String?
  public let timeEstimateSecs: Double

  public init(
    depositAddress: String?, depositMemo: String? = nil, amountIn: String, amountOut: String,
    minAmountOut: String, deadline: String?, timeEstimateSecs: Double
  ) {
    self.depositAddress = depositAddress
    self.depositMemo = depositMemo
    self.amountIn = amountIn
    self.amountOut = amountOut
    self.minAmountOut = minAmountOut
    self.deadline = deadline
    self.timeEstimateSecs = timeEstimateSecs
  }
}
