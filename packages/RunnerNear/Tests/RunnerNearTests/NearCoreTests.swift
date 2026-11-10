//
//  NearCoreTests.swift
//  RunnerNearTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNearTesting
import Testing

@testable import RunnerNear

/// The byte-exact contract, through the live Rust core:
/// Swift and `apps/api` must agree on every digest or claim passes
/// fail closed on both sides.
struct NearCoreTests {

  private var core: LiveNearCore { LiveNearCore() }

  /// Minted from `apps/api/src/near.ts`: message "hello runner",
  /// nonce 32x0x07, recipient "runner-api".
  @Test
  func nep413MatchesServerVector() throws {
    let digest = try core.nep413DigestHex(
      message: "hello runner",
      nonceBase64: "BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc=",
      recipient: "runner-api"
    )
    #expect(digest == "1b2b2ba6fa70730b76c6a75789e4b0efb43b02407c5ed1e6c54415b6d85a1b66")
  }

  @Test
  func nep413RejectsShortNonce() {
    #expect(throws: NearError.self) {
      try core.nep413DigestHex(message: "m", nonceBase64: "AAAA", recipient: "r")
    }
  }

  /// RFC 8032 §7.1 TEST 1, via the NEAR `ed25519:<base58>` form.
  @Test
  func ed25519MatchesRFC8032() throws {
    let secretB64 = "nWGxne/9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A="
    let publicKey = "ed25519:FVen3X669xLzsi6N2V91DoiyzHzg1uAgqiT8jZ9nS96Z"
    let signature = try core.ed25519Sign(secretBase64: secretB64, messageHex: "")
    #expect(
      try core.ed25519Verify(publicKey: publicKey, messageHex: "", signatureBase64: signature))
    #expect(
      !(try core.ed25519Verify(publicKey: publicKey, messageHex: "00", signatureBase64: signature)))
  }

  @Test
  func keypairRoundTrips() throws {
    let pair = try core.ed25519Keypair()
    let signature = try core.ed25519Sign(secretBase64: pair.secretBase64, messageHex: "ab")
    #expect(
      try core.ed25519Verify(
        publicKey: pair.publicKey, messageHex: "ab", signatureBase64: signature))
    #expect(try core.implicitAccountID(publicKey: pair.publicKey).count == 64)
  }

  @Test
  func errorsMapToTypedCases() {
    #expect(throws: NearError.self) {
      try core.ed25519Sign(secretBase64: "AAAA", messageHex: "ab")
    }
  }

  /// Golden vector from `apps/api/src/nearTx.ts`: claim call against
  /// `treasury.ije.near`, gas 300 Tgas, deposit 0, nonce 2, max block 150.
  private var claimArgs: String {
    #"{"attestation":"AAA","signature":"BBB","merchant_id":"mamaput.near","amount_cents":100}"#
  }

  private static func bytes(hex: String) -> Data {
    var data = Data()
    var index = hex.startIndex
    while index < hex.endIndex {
      let next = hex.index(index, offsetBy: 2)
      data.append(UInt8(hex[index..<next], radix: 16) ?? 0)
      index = next
    }
    return data
  }

  private var claimDelegateHex: String {
    "0a000000616c6963652e6e6561721100000074726561737572792e696a652e6e656172010000000205000000636c61696d570000007b226174746573746174696f6e223a22414141222c227369676e6174757265223a22424242222c226d65726368616e745f6964223a226d616d617075742e6e656172222c22616d6f756e745f63656e7473223a3130307d00c06e31d9100100000000000000000000000000000000000200000000000000960000000000000000ea4a6c63e29c520abef5507b132ec5f9954776aebebe7b92421eea691446d22c"
  }

  private func claimDelegate() throws -> String {
    try core.encodeDelegateAction(
      senderID: "alice.near",
      receiverID: "treasury.ije.near",
      methodName: "claim",
      argsJSON: claimArgs,
      gas: 300_000_000_000_000,
      depositYocto: "0",
      nonce: 2,
      maxBlockHeight: 150,
      publicKey: "ed25519:GmaDrppBC7P5ARKV8g3djiwP89vz1jLK23V2GBjuAEGB"
    )
  }

  @Test
  func delegateEncodingMatchesServerVector() throws {
    let raw = try #require(Data(base64Encoded: claimDelegate()))
    #expect(raw == Self.bytes(hex: claimDelegateHex))
  }

  @Test
  func delegateDigestMatchesServerVector() throws {
    let digest = try core.nep366DigestHex(delegateB64: claimDelegate())
    #expect(digest == "a98b8631fdcb7b5e790fb310d572aa243bebdec748d5ac5b75262252587403bd")
  }

  @Test
  func signedDelegateMatchesServerVector() throws {
    let secret = Data(repeating: 7, count: 32).base64EncodedString()
    let digest = try core.nep366DigestHex(delegateB64: claimDelegate())
    let signature = try core.ed25519Sign(secretBase64: secret, messageHex: digest)
    let signed = try core.encodeSignedDelegate(
      delegateB64: claimDelegate(), signatureB64: signature)
    let raw = try #require(Data(base64Encoded: signed))
    let delegateRaw = try #require(Data(base64Encoded: claimDelegate()))
    #expect(raw.starts(with: delegateRaw))
    let tail = raw.dropFirst(delegateRaw.count)
    #expect(tail.count == 65 && tail.first == 0x00)
    #expect(Data(tail.dropFirst()).base64EncodedString() == signature)
  }

  @Test
  func delegateBuildersRejectBadInput() {
    #expect(throws: NearError.self) {
      try core.nep366DigestHex(delegateB64: "!!!")
    }
  }

  @Test
  func mockCoreStaysHonest() throws {
    let mock = MockNearCore()
    mock.scriptNep413("digest")
    #expect(try mock.nep413DigestHex(message: "m", nonceBase64: "n", recipient: "r") == "digest")
    #expect(mock.recordedNep413Inputs.count == 1)
    #expect(throws: NearError.self) {
      _ = try mock.ed25519Keypair()
    }
  }
}
