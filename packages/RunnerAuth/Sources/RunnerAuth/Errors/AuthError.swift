//
//  AuthError.swift
//  RunnerAuth
//
//  Created by Peter on 09/11/2026.
//

/// Every failure mode of auth, typed once. Callers branch on cases,
/// never on text.
public enum AuthError: Sendable, Equatable, Error {

  case malformedToken
  case unreadableClaims
  case wrongIssuer
  case wrongAudience
  case nonceMismatch
  case tokenExpired
  case noSession
  case keychain(Int32)
}
