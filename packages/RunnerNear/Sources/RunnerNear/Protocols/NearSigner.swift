//
//  NearSigner.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// The signing seam the app (and later `RunnerAuth`) programs against.
/// Two backends, one shape: `FastAuthSigner` (every signature is an MPC
/// request authenticated by a fatxn-bound ceremony JWT) and
/// `LocalKeySigner` (the device key signs directly, `idToken` always
/// empty). No social logins on either path.
public protocol NearSigner: Sendable {

  var account: NearAccount { get async throws }

  /// NEP-413 message signature for claim passes. The JWT must come from
  /// the signature ceremony with this exact message bound as `fatxn` —
  /// anything else fails closed. `callbackUrl` is rejected: `apps/api`
  /// verifies only the no-callback digest.
  func signNep413(message: String, nonce: Data, recipient: String, idToken: String) async throws
    -> String

  /// MPC-signs an unsigned (Borsh base64) transaction's hash.
  func signTransaction(unsignedBase64: String, idToken: String) async throws -> String

  /// Broadcasts a signed transaction, waiting for commitment.
  func broadcast(signedBase64: String) async throws -> String
}
