//
//  MpcAccountResolver.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// Resolves the login to its deterministic NEAR identity: the derivation
/// path is pure string building (`jwt#https://<domain>/#<sub>`), the key
/// comes from the MPC contract's `derived_public_key` view, and the
/// account id is the key's implicit account. Verified live on testnet.
public struct MpcAccountResolver: AccountResolver, Sendable {

  private let network: NearNetwork
  private let rpc: any NearRpcFunctions
  private let core: any NearCoreFunctions

  public init(network: NearNetwork, rpc: any NearRpcFunctions, core: any NearCoreFunctions) {
    self.network = network
    self.rpc = rpc
    self.core = core
  }

  public func resolve(session: PasskeySession) async throws -> NearAccount {
    let path = Self.derivationPath(authDomain: network.authDomain, subject: session.subject)
    let key = try await rpc.mpcPublicKey(
      mpcContract: network.mpcContract,
      fastAuthContract: network.fastAuthContract,
      path: path
    )
    let accountID = try core.implicitAccountID(publicKey: key)
    return NearAccount(accountID: accountID, publicKey: key)
  }

  /// `jwt#https://<domain>/#<sub>` — the exact shape the fast-auth
  /// contract derives from. Matches Peersyst's `getPath`.
  public static func derivationPath(authDomain: String, subject: String) -> String {
    "jwt#https://\(authDomain)/#\(subject)"
  }
}
