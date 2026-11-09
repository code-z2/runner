//
//  NearAccount.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

/// A resolved NEAR account: the caller's identity for nonces, tx headers,
/// and claim passes. Derived deterministically per login — resolution
/// runs once per session, then caches.
public struct NearAccount: Sendable, Equatable {

  public let accountID: String
  public let publicKey: String

  public init(accountID: String, publicKey: String) {
    self.accountID = accountID
    self.publicKey = publicKey
  }
}
