//
//  LocalSignerTests.swift
//  RunnerNearTests
//
//  Created by Peter on 10/11/2026.
//

import Foundation
import RunnerNearTesting
import Testing

@testable import RunnerNear

struct LocalSignerTests {

  private func signer(
    core: MockNearCore = MockNearCore(),
    rpc: MockNearRpc = MockNearRpc()
  ) -> (LocalKeySigner, MockNearCore, MockNearRpc) {
    (
      LocalKeySigner(
        secretBase64: "c2VjcmV0",
        account: NearAccount(accountID: "abc.near", publicKey: "ed25519:xyz"),
        core: core, rpc: rpc),
      core, rpc
    )
  }

  @Test
  func accountPassesThrough() async throws {
    let (signer, _, _) = signer()
    #expect(try await signer.account.accountID == "abc.near")
  }

  @Test
  func nep413SignsDigestWithDeviceKey() async throws {
    let (signer, core, _) = signer()
    await core.scriptNep413("ab12")
    await core.scriptSignature("c2lnbmF0dXJl")
    let signature = try await signer.signNep413(
      message: "m", nonce: Data(repeating: 1, count: 32), recipient: "r.near", idToken: "")
    #expect(signature == "c2lnbmF0dXJl")
  }

  @Test
  func nonceMustBe32Bytes() async {
    let (signer, _, _) = signer()
    await #expect(throws: NearError.self) {
      try await signer.signNep413(
        message: "m", nonce: Data([1, 2, 3]), recipient: "r.near", idToken: "")
    }
  }

  @Test
  func ceremonyTokenIsRefused() async {
    let (signer, _, _) = signer()
    await #expect(throws: NearError.self) {
      try await signer.signNep413(
        message: "m", nonce: Data(repeating: 1, count: 32), recipient: "r.near", idToken: "jwt")
    }
    await #expect(throws: NearError.self) {
      try await signer.signTransaction(unsignedBase64: "dHhu", idToken: "jwt")
    }
  }

  @Test
  func transactionSignsHashWithDeviceKey() async throws {
    let (signer, core, _) = signer()
    await core.scriptTxHash("beef")
    await core.scriptSignature("c2lnbmF0dXJl")
    let signature = try await signer.signTransaction(unsignedBase64: "dHhu", idToken: "")
    #expect(signature == "c2lnbmF0dXJl")
  }

  @Test
  func broadcastReturnsHashOrThrows() async throws {
    let (signer, _, rpc) = signer()
    await rpc.scriptBroadcast(RpcTxOutcome(txHashHex: "hash-1", success: true, failure: nil))
    #expect(try await signer.broadcast(signedBase64: "c2lnbmVk") == "hash-1")
    await rpc.scriptBroadcast(RpcTxOutcome(txHashHex: "", success: false, failure: "refused"))
    await #expect(throws: NearError.self) {
      try await signer.broadcast(signedBase64: "c2lnbmVk")
    }
  }
}
