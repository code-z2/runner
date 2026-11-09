//
//  IntentTests.swift
//  RunnerNearTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNearTesting
import Testing

@testable import RunnerNear

struct IntentTests {

  private func request(dry: Bool) -> IntentQuoteRequest {
    IntentQuoteRequest(
      dry: dry, swapType: "EXACT_INPUT", slippageBps: 100,
      originAsset: "nep141:wrap.near", depositType: "ORIGIN_CHAIN",
      destinationAsset: "nep141:arb-0xabc.omft.near", amount: "1000000000000000000000000",
      refundTo: "alice.near", refundType: "ORIGIN_CHAIN",
      recipient: "0xabc", recipientType: "DESTINATION_CHAIN",
      deadline: "2030-01-01T00:00:00.000Z"
    )
  }

  @Test
  func emptyApiKeyFailsFast() {
    #expect(throws: NearError.self) {
      try LiveIntentClient(baseURL: "https://1click.chaindefuser.com", apiKey: "")
    }
  }

  @Test
  func dryQuoteThenWetQuoteThenSubmitThenSuccess() async throws {
    let intents = MockIntentClient()
    await intents.scriptQuote(
      IntentQuote(
        depositAddress: nil, amountIn: "1", amountOut: "2", minAmountOut: "2",
        deadline: nil, timeEstimateSecs: 12.5
      ))
    await intents.scriptQuote(
      IntentQuote(
        depositAddress: "dep-addr", amountIn: "1", amountOut: "2", minAmountOut: "2",
        deadline: "2030-01-01T00:00:00.000Z", timeEstimateSecs: 12.5
      ))
    await intents.scriptReport(IntentStatusReport(status: .knownDepositTx, updatedAt: "t1"))
    await intents.scriptReport(IntentStatusReport(status: .success, updatedAt: "t2"))

    let dry = try await intents.quote(request(dry: true))
    #expect(dry.depositAddress == nil)
    let wet = try await intents.quote(request(dry: false))
    #expect(wet.depositAddress == "dep-addr")

    let submitted = try await intents.submitDeposit(depositAddress: "dep-addr", txHash: "0xhash")
    #expect(submitted.status == .knownDepositTx)
    #expect(!submitted.status.isTerminal)

    let final = try await intents.status(depositAddress: "dep-addr")
    #expect(final.status == .success)
    #expect(final.status.isTerminal)
  }

  @Test
  func failedSwapIsTerminal() async throws {
    let intents = MockIntentClient()
    await intents.scriptReport(IntentStatusReport(status: .failed, updatedAt: "t"))
    let report = try await intents.status(depositAddress: "dep-addr")
    #expect(report.status.isTerminal)
    #expect(report.status == .failed)
  }

  @Test
  func unscriptedFlowFailsClosed() async throws {
    let intents = MockIntentClient()
    await #expect(throws: NearError.self) {
      try await intents.quote(self.request(dry: true))
    }
    await #expect(throws: NearError.self) {
      try await intents.status(depositAddress: "dep-addr")
    }
  }
}
