//
//  FastAuthSigner.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// MPC-backed signer. Digests and tx assembly come from the Rust core
/// (byte-exact with `apps/api`); every signature is an MPC request
/// authenticated by a fatxn-bound ceremony JWT. No local keys exist.
/// `guard_id` routes as `jwt#https://<domain>/` — the router prefix plus
/// the Auth0 guard name, matching the JS provider exactly.
public struct FastAuthSigner: NearSigner, Sendable {

  private let provider: any PasskeyProvider
  private let resolver: any AccountResolver
  private let core: any NearCoreFunctions
  private let rpc: any NearRpcFunctions
  private let submitter: any SignSubmitter
  private let network: NearNetwork

  public init(
    provider: any PasskeyProvider,
    resolver: any AccountResolver,
    core: any NearCoreFunctions,
    rpc: any NearRpcFunctions,
    submitter: any SignSubmitter,
    network: NearNetwork
  ) {
    self.provider = provider
    self.resolver = resolver
    self.core = core
    self.rpc = rpc
    self.submitter = submitter
    self.network = network
  }

  public var account: NearAccount {
    get async throws {
      guard let session = try await provider.session() else {
        throw NearError.notLoggedIn
      }
      return try await resolver.resolve(session: session)
    }
  }

  public func signNep413(message: String, nonce: Data, recipient: String, idToken: String)
    async throws -> String
  {
    guard nonce.count == 32 else {
      throw NearError.invalidInput("NEP-413 nonce must be 32 bytes")
    }
    let digestHex = try core.nep413DigestHex(
      message: message,
      nonceBase64: nonce.base64EncodedString(),
      recipient: recipient
    )
    let digest = try hexBytes(digestHex)
    try assertFatxn(idToken: idToken, expectedHex: digestHex)
    let signature = try await submitter.submit(
      guardID: Self.guardID(authDomain: network.authDomain),
      jwt: idToken,
      signPayload: digest,
      algorithm: .edwards
    )
    guard signature.count == 64 else {
      throw NearError.crypto("MPC signature is not 64 bytes")
    }
    return signature.base64EncodedString()
  }

  public func signTransaction(unsignedBase64: String, idToken: String) async throws -> String {
    let hashHex = try core.txSigningHash(unsignedBase64: unsignedBase64)
    let hash = try hexBytes(hashHex)
    try assertFatxn(idToken: idToken, expectedHex: hashHex)
    let signature = try await submitter.submit(
      guardID: Self.guardID(authDomain: network.authDomain),
      jwt: idToken,
      signPayload: hash,
      algorithm: .edwards
    )
    guard signature.count == 64 else {
      throw NearError.crypto("MPC signature is not 64 bytes")
    }
    // The public key is embedded in the unsigned tx; attach verifies match.
    return signature.base64EncodedString()
  }

  public func broadcast(signedBase64: String) async throws -> String {
    let outcome = try await rpc.broadcastCommit(signedTxBase64: signedBase64)
    guard outcome.success else {
      throw NearError.chain(code: "broadcast_failed", detail: outcome.failure ?? "unknown")
    }
    return outcome.txHashHex
  }

  /// `jwt#https://<domain>/` — router prefix + Auth0 guard name.
  public static func guardID(authDomain: String) -> String {
    "jwt#https://\(authDomain)/"
  }

  private func assertFatxn(idToken: String, expectedHex: String) throws {
    let bound = try provider.fatxnPayload(jwt: idToken)
    let boundHex = bound.map { String(format: "%02x", $0) }.joined()
    guard boundHex == expectedHex.lowercased() else {
      throw NearError.fatxnMismatch
    }
  }

  private func hexBytes(_ hex: String) throws -> Data {
    var data = Data()
    var index = hex.startIndex
    while index < hex.endIndex {
      let next = hex.index(index, offsetBy: 2)
      guard next <= hex.endIndex, let byte = UInt8(hex[index..<next], radix: 16) else {
        throw NearError.crypto("undigestable hex")
      }
      data.append(byte)
      index = next
    }
    return data
  }
}
