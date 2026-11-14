//
//  IntentTests.swift
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import Testing

@testable import RunnerNear

struct IntentTests {

  private let worker = URL(string: "https://worker.example")!

  private let request = IntentQuoteRequest(
    dry: false, swapType: "EXACT_OUTPUT", slippageBps: 100,
    originAsset: "nep141:base-0xabc.omft.near", depositType: "ORIGIN_CHAIN",
    destinationAsset: "nep141:usdc.near", amount: "5000000",
    refundTo: "0x1234567890123456789012345678901234567890", refundType: "ORIGIN_CHAIN",
    recipient: "escrow.near", recipientType: "DESTINATION_CHAIN",
    deadline: "2030-01-01T00:00:00.000Z", customRecipientMsg: #"{"owner":"a"}"#)

  @Test
  func assertsTheExactSDKBodyAndDecodesTheUpstreamQuote() async throws {
    let worker = worker
    let client = ProxiedIntentClient(
      baseURL: worker,
      send: { request in
        #expect(request.url?.absoluteString == "https://worker.example/v1/intents/v0/quote")
        #expect(request.value(forHTTPHeaderField: "x-runner-key-id") == "key")
        let body = try #require(request.httpBody)
        #expect(
          request.value(forHTTPHeaderField: "x-runner-assertion")
            == ProxiedIntentClient.clientData(method: "POST", path: "/v0/quote", body: body))
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["customRecipientMsg"] as? String == #"{"owner":"a"}"#)
        #expect(json["swapType"] as? String == "EXACT_OUTPUT")
        return (
          Data(
            """
            {"quote":{"depositAddress":"0xdep","depositMemo":"memo","amountIn":"5010000",
            "amountInFormatted":"5.01","amountInUsd":"5.01","minAmountIn":"5010000",
            "amountOut":"5000000","amountOutFormatted":"5","amountOutUsd":"5",
            "minAmountOut":"5000000","deadline":"2030-01-01T00:00:00Z","timeEstimate":20}}
            """.utf8),
          HTTPURLResponse(url: worker, statusCode: 201, httpVersion: nil, headerFields: nil)!
        )
      },
      assert: { DeviceAssertion(keyID: "key", assertion: $0) })

    let quote = try await client.quote(request)
    #expect(quote.depositAddress == "0xdep")
    #expect(quote.depositMemo == "memo")
    #expect(quote.amountIn == "5010000")
  }

  @Test
  func surfacesTheUpstreamStatusAndMessage() async throws {
    let worker = worker
    let client = ProxiedIntentClient(
      baseURL: worker,
      send: { _ in
        (
          Data(#"{"message":"amount is too low"}"#.utf8),
          HTTPURLResponse(url: worker, statusCode: 400, httpVersion: nil, headerFields: nil)!
        )
      },
      assert: { _ in DeviceAssertion(keyID: "key", assertion: "a") })

    await #expect(throws: NearError.relayer(status: 400, code: "amount is too low")) {
      try await client.quote(request)
    }
  }
}
