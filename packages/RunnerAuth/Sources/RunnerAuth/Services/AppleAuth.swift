//
//  AppleAuth.swift
//  RunnerAuth
//
//  Created by Peter on 09/11/2026.
//

import CryptoKit
import Foundation

/// Sign in with Apple, minus presentation. The app presents
/// `ASAuthorizationController` and hands the credential fields here for
/// parsing and validation; the server verifies the same nonce independently.
public struct AppleAuth: Sendable {

  /// Apple’s issuer. Pinned, never configured.
  public static let issuer = "https://appleid.apple.com"

  public struct Nonce: Sendable, Equatable {
    /// 32 random bytes, base64. Kept client-side for nothing — the hash
    /// below is what travels.
    public let raw: String
    /// SHA-256 hex of the raw bytes. Goes in the request; the server
    /// checks this same value inside the token.
    public let hashed: String
  }

  /// 32 fresh random bytes with their SHA-256 hex.
  public static func makeNonce() -> Nonce {
    let raw = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
    let hashed = Data(SHA256.hash(data: raw)).map { String(format: "%02x", $0) }.joined()
    return Nonce(raw: raw.base64EncodedString(), hashed: hashed)
  }

  /// Decode an identity token’s claims. Signature is the server’s job
  /// (Apple JWKS); this only shapes the payload for local checks.
  public static func claims(jwt: String) throws -> AppleIDClaims {
    let segments = jwt.split(separator: ".")
    guard segments.count >= 2 else { throw AuthError.malformedToken }
    var payload = String(segments[1])
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    while payload.count % 4 != 0 { payload += "=" }
    guard let data = Data(base64Encoded: payload),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { throw AuthError.malformedToken }
    guard let subject = json["sub"] as? String, !subject.isEmpty,
      let audience = json["aud"] as? String, !audience.isEmpty,
      let issuer = json["iss"] as? String, !issuer.isEmpty,
      let expirySeconds = json["exp"] as? Int
    else { throw AuthError.unreadableClaims }
    return AppleIDClaims(
      subject: subject,
      email: json["email"] as? String,
      emailVerified: (json["email_verified"] as? String) == "true",
      nonce: json["nonce"] as? String,
      audience: audience,
      issuer: issuer,
      expiry: Date(timeIntervalSince1970: TimeInterval(expirySeconds))
    )
  }

  /// Fail-closed local checks. The server repeats them against Apple’s
  /// JWKS with the signature; a token that fails here never travels.
  public static func validate(
    _ claims: AppleIDClaims, audience: String, requestHash: String, now: Date = Date()
  ) throws {
    guard claims.issuer == issuer else { throw AuthError.wrongIssuer }
    guard claims.audience == audience else { throw AuthError.wrongAudience }
    guard claims.nonce == requestHash else { throw AuthError.nonceMismatch }
    guard claims.expiry > now else { throw AuthError.tokenExpired }
  }
}
