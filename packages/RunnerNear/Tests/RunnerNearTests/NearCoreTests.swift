//
//  NearCoreTests.swift
//  RunnerNearTests
//
//  Created by Peter on 09/11/2026.
//

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
