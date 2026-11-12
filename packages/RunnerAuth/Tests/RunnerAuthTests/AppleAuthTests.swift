//
//  AppleAuthTests.swift
//  RunnerAuthTests
//
//  Created by Peter on 09/11/2026.
//

import CryptoKit
import Foundation
import Testing

@testable import RunnerAuth

struct AppleAuthTests {

  private func token(payload: [String: Any]) -> String {
    func b64(_ json: String) -> String {
      Data(json.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    }
    let body = String(data: try! JSONSerialization.data(withJSONObject: payload), encoding: .utf8)!
    return b64(#"{"alg":"ES256"}"#) + "." + b64(body) + ".sig"
  }

  private func claims(nonce: String? = "hashed-nonce", exp: Int = 9_999_999_999) -> [String: Any] {
    var payload: [String: Any] = [
      "iss": "https://appleid.apple.com",
      "aud": "io.wades.ije",
      "sub": "apple-user-1",
      "exp": exp,
      "email": "runner@privaterelay.appleid.com",
      "email_verified": "true",
    ]
    if let nonce { payload["nonce"] = nonce }
    return payload
  }

  @Test
  func nonceIs32RandomBytesWithMatchingHash() {
    let first = AppleAuth.makeNonce()
    let second = AppleAuth.makeNonce()
    #expect(first.raw != second.raw)
    #expect(Data(base64Encoded: first.raw)?.count == 32)
    let hashed = Data(SHA256.hash(data: Data(base64Encoded: first.raw)!))
      .map { String(format: "%02x", $0) }.joined()
    #expect(first.hashed == hashed)
  }

  @Test
  func parsesIdentityClaims() throws {
    let parsed = try AppleAuth.claims(jwt: token(payload: claims()))
    #expect(parsed.subject == "apple-user-1")
    #expect(parsed.email == "runner@privaterelay.appleid.com")
    #expect(parsed.emailVerified)
    #expect(parsed.audience == "io.wades.ije")
    #expect(parsed.issuer == "https://appleid.apple.com")
    #expect(parsed.nonce == "hashed-nonce")
  }

  @Test
  func validatesHappyPath() throws {
    let parsed = try AppleAuth.claims(jwt: token(payload: claims()))
    try AppleAuth.validate(parsed, audience: "io.wades.ije", requestHash: "hashed-nonce")
  }

  @Test
  func rejectsWrongIssuerAudienceNonceExpiry() {
    var bad = claims()
    bad["iss"] = "https://evil.example.com"
    #expect(throws: AuthError.wrongIssuer) {
      try AppleAuth.validate(
        AppleAuth.claims(jwt: token(payload: bad)), audience: "io.wades.ije",
        requestHash: "hashed-nonce")
    }
    bad = claims()
    bad["aud"] = "other.app"
    #expect(throws: AuthError.wrongAudience) {
      try AppleAuth.validate(
        AppleAuth.claims(jwt: token(payload: bad)), audience: "io.wades.ije",
        requestHash: "hashed-nonce")
    }
    #expect(throws: AuthError.nonceMismatch) {
      try AppleAuth.validate(
        AppleAuth.claims(jwt: token(payload: claims())), audience: "io.wades.ije",
        requestHash: "other-hash")
    }
    bad = claims(exp: 1)
    #expect(throws: AuthError.tokenExpired) {
      try AppleAuth.validate(
        AppleAuth.claims(jwt: token(payload: bad)), audience: "io.wades.ije",
        requestHash: "hashed-nonce")
    }
  }

  @Test
  func malformedTokenFails() {
    #expect(throws: AuthError.malformedToken) { try AppleAuth.claims(jwt: "not-a-jwt") }
    #expect(throws: AuthError.unreadableClaims) {
      try AppleAuth.claims(jwt: token(payload: ["iss": "https://appleid.apple.com"]))
    }
  }
}
