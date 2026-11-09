//
//  LiveIntentClient.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNearCore

/// Production 1Click client: thin delegation to the Rust core, errors
/// mapped once. The api key is partner-level config, not a user secret.
public struct LiveIntentClient: IntentFunctions, Sendable {

  private let inner: RunnerNearCore.NearIntents

  public init(baseURL: String = "https://1click.chaindefuser.com", apiKey: String) throws {
    do {
      inner = try RunnerNearCore.NearIntents(baseUrl: baseURL, apiKey: apiKey)
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  public func tokens() throws -> [IntentToken] {
    do {
      return try inner.tokens().map {
        IntentToken(
          assetID: $0.assetId, symbol: $0.symbol, decimals: $0.decimals,
          blockchain: $0.blockchain)
      }
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  public func quote(_ request: IntentQuoteRequest) throws -> IntentQuote {
    do {
      let out = try inner.quote(
        req: RunnerNearCore.IntentQuoteRequest(
          dry: request.dry,
          swapType: request.swapType,
          slippageBps: request.slippageBps,
          originAsset: request.originAsset,
          depositType: request.depositType,
          destinationAsset: request.destinationAsset,
          amount: request.amount,
          refundTo: request.refundTo,
          refundType: request.refundType,
          recipient: request.recipient,
          recipientType: request.recipientType,
          deadline: request.deadline
        ))
      return IntentQuote(
        depositAddress: out.depositAddress,
        amountIn: out.amountIn,
        amountOut: out.amountOut,
        minAmountOut: out.minAmountOut,
        deadline: out.deadline,
        timeEstimateSecs: out.timeEstimateSecs
      )
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  public func submitDeposit(depositAddress: String, txHash: String) throws -> IntentStatusReport {
    do {
      let report = try inner.submitDeposit(depositAddress: depositAddress, txHash: txHash)
      return IntentStatusReport(status: mapStatus(report.status), updatedAt: report.updatedAt)
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  public func status(depositAddress: String) throws -> IntentStatusReport {
    do {
      let report = try inner.status(depositAddress: depositAddress)
      return IntentStatusReport(status: mapStatus(report.status), updatedAt: report.updatedAt)
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  private func mapStatus(_ status: RunnerNearCore.IntentStatus) -> IntentStatus {
    switch status {
    case .pendingDeposit: return .pendingDeposit
    case .knownDepositTx: return .knownDepositTx
    case .incompleteDeposit: return .incompleteDeposit
    case .processing: return .processing
    case .success: return .success
    case .refunded: return .refunded
    case .failed: return .failed
    }
  }
}
