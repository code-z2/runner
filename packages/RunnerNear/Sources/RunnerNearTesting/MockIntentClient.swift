//
//  MockIntentClient.swift
//  RunnerNearTesting
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// Scripted 1Click: canned answers, recorded calls. Live mainnet behavior
/// is proven with small-amount swaps, never here.
public actor MockIntentClient: IntentFunctions {

  private var tokenList: [IntentToken] = []
  private var quotes: [IntentQuote] = []
  private var reports: [IntentStatusReport] = []

  public private(set) var quoteRequests: [IntentQuoteRequest] = []
  public private(set) var submissions: [(depositAddress: String, txHash: String)] = []
  public private(set) var statusPolls: [String] = []

  public init() {}

  public func scriptTokens(_ values: [IntentToken]) { tokenList = values }
  public func scriptQuote(_ value: IntentQuote) { quotes.append(value) }
  public func scriptReport(_ value: IntentStatusReport) { reports.append(value) }

  public func tokens() throws -> [IntentToken] { tokenList }

  public func quote(_ request: IntentQuoteRequest) throws -> IntentQuote {
    quoteRequests.append(request)
    guard !quotes.isEmpty else { throw NearError.transport("no quote scripted") }
    return quotes.removeFirst()
  }

  public func submitDeposit(depositAddress: String, txHash: String) throws -> IntentStatusReport {
    submissions.append((depositAddress, txHash))
    guard !reports.isEmpty else { throw NearError.transport("no report scripted") }
    return reports.removeFirst()
  }

  public func status(depositAddress: String) throws -> IntentStatusReport {
    statusPolls.append(depositAddress)
    guard !reports.isEmpty else { throw NearError.transport("no report scripted") }
    return reports.removeFirst()
  }
}
