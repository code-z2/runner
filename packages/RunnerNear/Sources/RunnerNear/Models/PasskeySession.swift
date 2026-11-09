//
//  PasskeySession.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// An authenticated passkey session. The id token is the authority —
/// the MPC side verifies it, so it travels to the relayer on every
/// signature request. Secrets stay in the Keychain at the app layer;
/// this value never touches disk itself.
public struct PasskeySession: Sendable, Equatable {

  /// OIDC id token (JWT) from NEAR's Auth0 tenant.
  public let idToken: String

  public let refreshToken: String?

  public let expiresAt: Date

  /// Auth0 `sub` — the stable user id behind the login.
  public let subject: String

  public init(idToken: String, refreshToken: String?, expiresAt: Date, subject: String) {
    self.idToken = idToken
    self.refreshToken = refreshToken
    self.expiresAt = expiresAt
    self.subject = subject
  }

  public func isExpired(now: Date = Date()) -> Bool {
    now >= expiresAt.addingTimeInterval(-60)
  }
}
