//
//  GatewayClientTests.swift
//  RunnerGatewayTests
//
//  Created by Peter on 08/11/2026.
//

import Foundation
import RunnerGatewayTesting
import Testing

@testable import RunnerGateway

struct GatewayClientTests {

  private func client(
    transport: MockHTTPTransport = MockHTTPTransport(),
    baseURL: URL = URL(string: "https://runner-api.test")!
  ) throws -> (RunnerGatewayClient, MockHTTPTransport) {
    (try RunnerGatewayClient(baseURL: baseURL, transport: transport), transport)
  }

  private func json(_ value: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: value)
  }

  @Test
  func rejectsNonHTTPBaseURL() {
    #expect(throws: GatewayError.self) {
      try RunnerGatewayClient(
        baseURL: URL(string: "ftp://runner-api.test")!,
        transport: MockHTTPTransport()
      )
    }
  }

  @Test
  func challengePostsToV1AndDecodes() async throws {
    let transport = MockHTTPTransport()
    let (client, _) = try self.client(transport: transport)
    await transport.enqueue(try json(["challenge": "abc123"]), status: 201)
    let challenge = try await client.challenge()
    #expect(challenge.value == "abc123")
    let request = await transport.lastRequest
    #expect(request?.httpMethod == "POST")
    #expect(request?.url?.path == "/v1/challenge")
  }

  @Test
  func registerDeviceSendsSnakeCaseBody() async throws {
    let transport = MockHTTPTransport()
    let (client, _) = try self.client(transport: transport)
    await transport.enqueue(try json(["key_id": "key-1"]), status: 201)
    let keyID = try await client.registerDevice(
      DeviceRegistration(keyID: "key-1", attestation: "att", challenge: "ch")
    )
    #expect(keyID == "key-1")
    let request = await transport.lastRequest
    #expect(request?.url?.path == "/v1/devices")
    let rawBody = try #require(request?.httpBody)
    let decoded = try JSONSerialization.jsonObject(with: rawBody)
    let body = try #require(decoded as? [String: String])
    #expect(body["key_id"] == "key-1")
    #expect(body["attestation"] == "att")
    #expect(body["challenge"] == "ch")
  }

  @Test
  func claimPassDecodesNestedAttestation() async throws {
    let transport = MockHTTPTransport()
    let (client, _) = try self.client(transport: transport)
    let inner = try json([
      "v": 1, "account_id": "runner.ije.near", "activity_hash": "deadbeef",
      "max_amount_cents": 256, "expires_at": 1_761_000_000, "nonce": "n-1",
    ])
    await transport.enqueue(
      try json(["attestation": String(data: inner, encoding: .utf8), "signature": "sig"]),
      status: 201
    )
    let pass = try await client.claimPass(
      ClaimPassRequest(
        payload: "payload", keyID: "key-1", assertion: "assert",
        nearPublicKey: "ed25519:abc", nearSignature: "sig"
      )
    )
    #expect(pass.accountID == "runner.ije.near")
    #expect(pass.maxAmountCents == 256)
    #expect(pass.activityHash == "deadbeef")
    let request = await transport.lastRequest
    #expect(request?.url?.path == "/v1/attestations")
  }

  @Test
  func serverErrorMapsToTypedError() async throws {
    let transport = MockHTTPTransport()
    let (client, _) = try self.client(transport: transport)
    await transport.enqueue(try json(["error": "too_soon"]), status: 409)
    await #expect(throws: GatewayError.server(status: 409, code: "too_soon")) {
      try await client.claimPass(
        ClaimPassRequest(
          payload: "p", keyID: "k", assertion: "a",
          nearPublicKey: "n", nearSignature: "s"
        )
      )
    }
  }

  @Test
  func misconfiguredServerSurfaces() async throws {
    let transport = MockHTTPTransport()
    let (client, _) = try self.client(transport: transport)
    await transport.enqueue(try json(["error": "misconfigured"]), status: 503)
    await #expect(throws: GatewayError.server(status: 503, code: "misconfigured")) {
      try await client.registerDevice(
        DeviceRegistration(keyID: "k", attestation: "a", challenge: "c")
      )
    }
  }

  @Test
  func merchantsQueryCellsAndDecode() async throws {
    let transport = MockHTTPTransport()
    let (client, _) = try self.client(transport: transport)
    await transport.enqueue(
      try json([
        "locations": [
          [
            "id": "loc-1", "name": "Water Stop", "lat": 51.5, "lng": -0.1,
            "categories": ["water"], "near_account": "shop.near",
          ]
        ]
      ]),
      status: 200
    )
    let locations = try await client.merchants(cells: ["u10j8", "u10j9"])
    #expect(locations.count == 1)
    #expect(locations[0].name == "Water Stop")
    #expect(locations[0].nearAccount == "shop.near")
    let request = await transport.lastRequest
    #expect(request?.httpMethod == "GET")
    #expect(request?.url?.path == "/v1/merchants")
    #expect(request?.url?.query?.contains("cells=") == true)
  }

  @Test
  func merchantsRejectEmptyCells() async throws {
    let (client, _) = try self.client()
    await #expect(throws: GatewayError.self) {
      try await client.merchants(cells: [])
    }
  }

  @Test
  func transportFailureWraps() async throws {
    let (client, _) = try self.client()
    // Nothing enqueued: the mock throws a transport error.
    await #expect(throws: GatewayError.self) {
      try await client.challenge()
    }
  }

  @Test
  func seedPostsAccountAndDecodesCreated() async throws {
    let transport = MockHTTPTransport()
    let (client, _) = try self.client(transport: transport)
    await transport.enqueue(try json(["seeded": true, "tx": "tx-1"]), status: 200)
    let result = try await client.seed(SeedRequest(accountID: "abc.near"))
    #expect(result == SeedResult(seeded: true, txHash: "tx-1"))
    let request = await transport.lastRequest
    #expect(request?.httpMethod == "POST")
    #expect(request?.url?.path == "/v1/seed")
    let rawBody = try #require(request?.httpBody)
    let decoded = try JSONSerialization.jsonObject(with: rawBody)
    let body = try #require(decoded as? [String: String])
    #expect(body == ["account_id": "abc.near"])
  }

  @Test
  func seedExistingAccountReturnsUnseeded() async throws {
    let transport = MockHTTPTransport()
    let (client, _) = try self.client(transport: transport)
    await transport.enqueue(try json(["seeded": false]), status: 200)
    let result = try await client.seed(SeedRequest(accountID: "abc.near"))
    #expect(result == SeedResult(seeded: false))
  }

  @Test
  func dryFunderMapsToTypedError() async throws {
    let transport = MockHTTPTransport()
    let (client, _) = try self.client(transport: transport)
    await transport.enqueue(try json(["error": "funder_dry"]), status: 503)
    await #expect(throws: GatewayError.server(status: 503, code: "funder_dry")) {
      try await client.seed(SeedRequest(accountID: "abc.near"))
    }
  }
}
