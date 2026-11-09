//
//  AuthFlow.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import CryptoKit
import Foundation
import RunnerAuth
import RunnerNear

/// The sign-in state machine. Apple first, then the NEAR passkey ceremony —
/// each step stores its pending values and verifies the answer belongs to
/// the question asked (state match, fatxn match) before linking anything.
actor AuthFlow {

  private let provider: any PasskeyProvider

  private let coordinator: RunnerAuthCoordinator

  private let redirectURI: String

  private let appleAudience: String

  private let resolveAccount: @Sendable (PasskeySession) async throws -> NearAccount

  private var appleNonce: AppleAuth.Nonce?

  private var pendingLogin: (verifier: String, state: String)?

  private var pendingSignature: (verifier: String, state: String, payloadHex: String)?

  init(
    provider: any PasskeyProvider,
    coordinator: RunnerAuthCoordinator,
    redirectURI: String,
    appleAudience: String,
    resolveAccount: @escaping @Sendable (PasskeySession) async throws -> NearAccount
  ) {
    self.provider = provider
    self.coordinator = coordinator
    self.redirectURI = redirectURI
    self.appleAudience = appleAudience
    self.resolveAccount = resolveAccount
  }

  // MARK: - Apple

  /// Starts Apple sign-in. Returns the hashed nonce for the request; the
  /// raw value stays here for the answer check. Presentation is the
  /// adapter's job.
  func beginApple() -> String {
    let nonce = AppleAuth.makeNonce()
    appleNonce = nonce
    return nonce.hashed
  }

  /// Completes Apple sign-in: parses and validates the identity token,
  /// then links the identity. Throws when the answer doesn't match the
  /// question — including a missing `beginApple`.
  func completeApple(identityToken: String) async throws -> AppleIdentity {
    guard let nonce = appleNonce else { throw AuthError.noSession }
    appleNonce = nil
    let parsed = try AppleAuth.claims(jwt: identityToken)
    try AppleAuth.validate(parsed, audience: appleAudience, requestHash: nonce.hashed)
    let identity = AppleIdentity(
      userID: parsed.subject, email: parsed.email, givenName: nil, familyName: nil,
      identityToken: identityToken)
    try await coordinator.linkApple(identity)
    return identity
  }

  /// Routes an incoming universal link to whichever ceremony is pending.
  /// The app calls this only after the callback handler's allowlist
  /// passes; the pending values still decide login vs signature, and
  /// `AuthError.noSession` covers a callback with nothing outstanding.
  func completeCallback(_ url: URL) async throws {
    if pendingLogin != nil {
      _ = try await completeLoginCallback(url)
    } else if pendingSignature != nil {
      _ = try await completeSignatureCallback(url)
    } else {
      throw AuthError.noSession
    }
  }

  // MARK: - NEAR login

  /// Starts the passkey login. Returns the sheet URL; the app presents it
  /// with the modern session API and routes the callback here.
  func beginLogin() throws -> URL {
    let verifier = randomToken()
    let state = randomToken()
    pendingLogin = (verifier, state)
    return try provider.authorizeURL(
      redirectURI: redirectURI, state: state, codeChallenge: challenge(for: verifier))
  }

  /// Completes the login: state must match the pending one, then the
  /// code is exchanged and the session linked. Single-use — the pending
  /// values clear before the network call.
  func completeLoginCallback(_ url: URL) async throws -> PasskeySession {
    guard let pending = pendingLogin else { throw AuthError.noSession }
    pendingLogin = nil
    let (code, state) = try callbackParts(from: url)
    guard state == pending.state else { throw AuthCallbackError.stateMismatch }
    let session = try await provider.completeLogin(
      callbackURL: callbackURL(code: code, state: state),
      codeVerifier: pending.verifier,
      redirectURI: redirectURI)
    let account = try await resolveAccount(session)
    try await coordinator.linkNear(session: session, account: account)
    return session
  }

  // MARK: - NEAR signature ceremony

  /// Starts one signing ceremony over `payload`. Returns the consent URL;
  /// the user approves with a passkey.
  func beginSignature(payload: SignaturePayload) throws -> URL {
    let verifier = randomToken()
    let state = randomToken()
    let payloadHex = payload.bytes.map { String(format: "%02x", $0) }.joined()
    pendingSignature = (verifier, state, payloadHex)
    return try provider.authorizeSignatureURL(
      payload: payload,
      redirectURI: redirectURI,
      state: state,
      codeChallenge: challenge(for: verifier))
  }

  /// Completes the ceremony: state match, code exchange with fatxn check
  /// (the provider refuses mismatches), account resolution, link.
  func completeSignatureCallback(_ url: URL) async throws -> NearAccount {
    guard let pending = pendingSignature else { throw AuthError.noSession }
    pendingSignature = nil
    let (code, state) = try callbackParts(from: url)
    guard state == pending.state else { throw AuthCallbackError.stateMismatch }
    let jwt = try await provider.completeSignatureCallback(
      callbackURL(code: code, state: state),
      codeVerifier: pending.verifier,
      redirectURI: redirectURI,
      expectedPayloadHex: pending.payloadHex)
    let session = try passkeySession(jwt: jwt)
    let account = try await resolveAccount(session)
    try await coordinator.linkNear(session: session, account: account)
    return account
  }

  // MARK: - Private

  private func callbackParts(from url: URL) throws -> (code: String, state: String) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
      !code.isEmpty,
      let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
      !state.isEmpty
    else { throw AuthCallbackError.missingCode }
    return (code, state)
  }

  private func callbackURL(code: String, state: String) -> URL {
    var components = URLComponents(string: redirectURI)!
    components.queryItems = [
      URLQueryItem(name: "code", value: code),
      URLQueryItem(name: "state", value: state),
    ]
    return components.url!
  }

  private func passkeySession(jwt: String) throws -> PasskeySession {
    let segments = jwt.split(separator: ".")
    guard segments.count >= 2 else { throw AuthError.malformedToken }
    var payload = String(segments[1])
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    while payload.count % 4 != 0 { payload += "=" }
    guard let data = Data(base64Encoded: payload),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let subject = json["sub"] as? String, !subject.isEmpty,
      let expiry = json["exp"] as? Int
    else { throw AuthError.unreadableClaims }
    return PasskeySession(
      idToken: jwt, refreshToken: nil,
      expiresAt: Date(timeIntervalSince1970: TimeInterval(expiry)), subject: subject)
  }

  private func randomToken() -> String {
    Data((0..<32).map { _ in UInt8.random(in: 0...255) })
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private func challenge(for verifier: String) -> String {
    Data(SHA256.hash(data: Data(verifier.utf8)))
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
