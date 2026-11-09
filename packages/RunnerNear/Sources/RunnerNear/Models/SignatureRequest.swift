//
//  SignatureRequest.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// What the MPC side needs: which guard verifies the JWT, the JWT
/// itself, and the exact bytes to sign. Mirrors Peersyst's
/// `SignatureRequest` (`@shared/core`) without the JS optionality.
public struct SignatureRequest: Sendable, Equatable {

  /// JWT provider identifier. Auth0 passkey logins use `"auth0"`.
  public let guardID: String

  /// The OIDC id token; the guard verifies it on-chain.
  public let verifyPayload: String

  /// Exact bytes the MPC network signs — tx Borsh or NEP-413 digest.
  public let signPayload: Data

  public enum Algorithm: String, Sendable, Equatable {
    case edwards = "eddsa"
    case secp256k1 = "secp256k1"
    case ecdsa = "ecdsa"
  }

  public let algorithm: Algorithm

  public init(guardID: String, verifyPayload: String, signPayload: Data, algorithm: Algorithm) {
    self.guardID = guardID
    self.verifyPayload = verifyPayload
    self.signPayload = signPayload
    self.algorithm = algorithm
  }
}
