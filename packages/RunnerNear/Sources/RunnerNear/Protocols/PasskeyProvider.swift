//
//  PasskeyProvider.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// Passkey-only Auth0 login against NEAR's tenant. The app layer presents
/// the authorize URL in an `ASWebAuthenticationSession` and hands the
/// callback URL back — this actor owns everything before and after the
/// sheet. No social logins; that choice is structural, not a flag.
public protocol PasskeyProvider: Sendable {

  /// The URL the app opens in the auth sheet.
  func authorizeURL(redirectURI: String, state: String, codeChallenge: String) throws -> URL

  /// Exchange the sheet's callback URL for a session.
  func completeLogin(callbackURL: URL, codeVerifier: String, redirectURI: String) async throws
    -> PasskeySession

  /// The live session, refreshed when expired and a refresh token exists.
  func session() async throws -> PasskeySession?

  func logout() async

  /// The authorize URL for one signature ceremony. The payload rides as a
  /// login parameter; NEAR's Auth0 Action binds it into the JWT's `fatxn`
  /// claim. The app presents this URL; the user approves with a passkey.
  func authorizeSignatureURL(
    payload: SignaturePayload,
    redirectURI: String,
    state: String,
    codeChallenge: String
  ) throws -> URL

  /// Exchange the ceremony callback for the fatxn-bound JWT, verifying the
  /// embedded payload equals `expectedPayloadHex`. Fail-closed on mismatch.
  func completeSignatureCallback(
    _ url: URL,
    codeVerifier: String,
    redirectURI: String,
    expectedPayloadHex: String
  ) async throws -> String

  /// The `fatxn` claim of a JWT as raw bytes. Pure decode, no verification —
  /// on-chain guards verify; this only checks the ceremony bound the payload.
  func fatxnPayload(jwt: String) throws -> Data
}

/// One signable payload, mirroring Peersyst's `SignatureRequestPayload`.
public enum SignaturePayload: Sendable, Equatable {

  case transaction(Data)
  case delegateAction(Data)
  case nep413(Data)

  /// The Auth0 parameter name the payload rides under.
  public var parameterName: String {
    switch self {
    case .transaction: return "transaction"
    case .delegateAction: return "delegateAction"
    case .nep413: return "nep413"
    }
  }

  public var bytes: Data {
    switch self {
    case .transaction(let data): return data
    case .delegateAction(let data): return data
    case .nep413(let data): return data
    }
  }
}
