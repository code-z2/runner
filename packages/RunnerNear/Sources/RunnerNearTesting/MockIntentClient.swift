//
//  MockIntentClient.swift
//  RunnerNearTesting
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// Scripted 1Click quote: canned answers, recorded calls. Live mainnet
/// behavior is proven with small-amount swaps, never here.
public actor MockIntentClient: IntentFunctions {

  private var quotes: [IntentQuote] = []

  public private(set) var quoteRequests: [IntentQuoteRequest] = []

  public init() {}

  public func scriptQuote(_ value: IntentQuote) { quotes.append(value) }

  public func quote(_ request: IntentQuoteRequest) throws -> IntentQuote {
    quoteRequests.append(request)
    guard !quotes.isEmpty else { throw NearError.transport("no quote scripted") }
    return quotes.removeFirst()
  }
}
