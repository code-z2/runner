//
//  LocalKeySigner.swift
//  RunnerNear
//
//  Created by Peter on 10/11/2026.
//

import Foundation

/// Device-key signer: the Keychain-held Ed25519 key signs locally, no
/// ceremony, no JWT. Takes the `NearSigner` shape so callers program
/// against the seam; the `idToken` is always empty on this path and
/// anything else fails closed.
public struct LocalKeySigner: NearSigner, Sendable {

  private let secretBase64: String

  private let accountValue: NearAccount

  private let core: any NearCoreFunctions

  private let rpc: any NearRpcFunctions

  public init(
    secretBase64: String,
    account: NearAccount,
    core: any NearCoreFunctions,
    rpc: any NearRpcFunctions
  ) {
    self.secretBase64 = secretBase64
    self.accountValue = account
    self.core = core
    self.rpc = rpc
  }

  public var account: NearAccount {
    get async throws { accountValue }
  }

  public func signNep413(message: String, nonce: Data, recipient: String, idToken: String)
    async throws -> String
  {
    try requireLocal(idToken)
    guard nonce.count == 32 else {
      throw NearError.invalidInput("NEP-413 nonce must be 32 bytes")
    }
    let digestHex = try core.nep413DigestHex(
      message: message,
      nonceBase64: nonce.base64EncodedString(),
      recipient: recipient
    )
    return try core.ed25519Sign(secretBase64: secretBase64, messageHex: digestHex)
  }

  public func signTransaction(unsignedBase64: String, idToken: String) async throws -> String {
    try requireLocal(idToken)
    let hashHex = try core.txSigningHash(unsignedBase64: unsignedBase64)
    return try core.ed25519Sign(secretBase64: secretBase64, messageHex: hashHex)
  }

  public func broadcast(signedBase64: String) async throws -> String {
    let outcome = try await rpc.broadcastCommit(signedTxBase64: signedBase64)
    guard outcome.success else {
      throw NearError.chain(code: "broadcast_failed", detail: outcome.failure ?? "unknown")
    }
    return outcome.txHashHex
  }

  private func requireLocal(_ idToken: String) throws {
    guard idToken.isEmpty else {
      throw NearError.invalidInput("local signer takes no idToken")
    }
  }
}
