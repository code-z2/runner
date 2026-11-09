//
//  TxPipelineTests.swift
//  RunnerNearTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNearTesting
import Testing

@testable import RunnerNear

/// The full local pipeline through the live core: build → hash → sign →
/// attach → broadcast. No network except the scripted RPC; MPC signatures
/// arrive via the ceremony in production, via RFC vectors here.
struct TxPipelineTests {

  private let secretB64 = "nWGxne/9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A="
  private let publicKey = "ed25519:FVen3X669xLzsi6N2V91DoiyzHzg1uAgqiT8jZ9nS96Z"
  private let otherKey = "ed25519:586Z7H2vpX9qNhN2T4e9Utugie3ogjbxzGaMtM3EHR5"
  private let blockHex = String(repeating: "ab", count: 32)

  private func transfer() throws -> String {
    try LiveNearCore().buildTransferTx(
      sender: "alice.testnet",
      receiver: "bob.testnet",
      publicKey: publicKey,
      nonce: 7,
      blockHashHex: blockHex,
      amountYocto: "1000000000000000000000000"
    )
  }

  @Test
  func buildHashAttachBroadcast() async throws {
    let core = LiveNearCore()
    let unsigned = try transfer()
    // Deterministic: same inputs, same bytes.
    #expect(try transfer() == unsigned)
    let hash = try core.txSigningHash(unsignedBase64: unsigned)
    #expect(hash.count == 64)
    let signature = try core.ed25519Sign(secretBase64: secretB64, messageHex: hash)
    let signed = try core.attachSignature(
      unsignedBase64: unsigned,
      signatureBase64: signature,
      publicKey: publicKey
    )
    let rpc = MockNearRpc()
    await rpc.scriptBroadcast(
      RpcTxOutcome(txHashHex: String(repeating: "cd", count: 32), success: true, failure: nil)
    )
    let outcome = try await rpc.broadcastCommit(signedTxBase64: signed)
    #expect(outcome.success)
    #expect(await rpc.broadcasts.count == 1)
  }

  @Test
  func attachRejectsWrongKey() throws {
    let core = LiveNearCore()
    let unsigned = try transfer()
    let hash = try core.txSigningHash(unsignedBase64: unsigned)
    let signature = try core.ed25519Sign(secretBase64: secretB64, messageHex: hash)
    #expect(throws: NearError.self) {
      try core.attachSignature(
        unsignedBase64: unsigned,
        signatureBase64: signature,
        publicKey: otherKey
      )
    }
  }

  @Test
  func broadcastFailureSurfaces() async throws {
    let rpc = MockNearRpc()
    await rpc.scriptBroadcast(
      RpcTxOutcome(txHashHex: "", success: false, failure: #"{"ActionError":{"index":0}}"#)
    )
    let signer = FastAuthSigner(
      provider: StaticProvider(fixed: nil),
      resolver: MockAccountResolver(
        account: NearAccount(accountID: "a", publicKey: "ed25519:b")
      ),
      core: LiveNearCore(),
      rpc: rpc,
      submitter: MockSignSubmitter(),
      network: NearNetwork.testnet(relayerURL: URL(string: "https://relayer.test")!)
    )
    let core = LiveNearCore()
    let unsigned = try transfer()
    let hash = try core.txSigningHash(unsignedBase64: unsigned)
    let signature = try core.ed25519Sign(secretBase64: secretB64, messageHex: hash)
    let signed = try core.attachSignature(
      unsignedBase64: unsigned,
      signatureBase64: signature,
      publicKey: publicKey
    )
    await #expect(throws: NearError.self) {
      _ = try await signer.broadcast(signedBase64: signed)
    }
  }
}
