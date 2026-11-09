//
//  NearKeypair.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

/// An Ed25519 keypair in NEAR wire form. Secrets cross this boundary as
/// base64 seeds; public keys as `ed25519:<base58>`.
public struct NearKeypair: Sendable, Equatable {

  public let secretBase64: String
  public let publicKey: String

  public init(secretBase64: String, publicKey: String) {
    self.secretBase64 = secretBase64
    self.publicKey = publicKey
  }
}
