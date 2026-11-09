//
//  MockAccountResolver.swift
//  RunnerNearTesting
//
//  Created by Peter on 09/11/2026.
//

import RunnerNear

/// Scripted account resolution. Tests pin the account; the live resolver
/// is verified against testnet before it ships.
public struct MockAccountResolver: AccountResolver, Sendable {

  public var account: NearAccount

  public init(account: NearAccount) {
    self.account = account
  }

  public func resolve(session: PasskeySession) async throws -> NearAccount {
    account
  }
}
