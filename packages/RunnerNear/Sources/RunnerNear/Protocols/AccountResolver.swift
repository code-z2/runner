//
//  AccountResolver.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

/// JWT → NEAR account resolution. The derivation path + public key come
/// from the fast-auth contract/relayer; the exact call is verified live
/// on testnet before the live implementation ships. Tests script this.
public protocol AccountResolver: Sendable {

  func resolve(session: PasskeySession) async throws -> NearAccount
}
