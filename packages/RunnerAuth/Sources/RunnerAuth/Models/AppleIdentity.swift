//
//  AppleIdentity.swift
//  RunnerAuth
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// What Sign in with Apple yields. Email and name arrive on first
/// presentation only — everything downstream treats them as optional.
public struct AppleIdentity: Sendable, Equatable, Codable {
  public let userID: String
  public let email: String?
  public let givenName: String?
  public let familyName: String?
  public let identityToken: String
  public init(
    userID: String, email: String?, givenName: String?, familyName: String?, identityToken: String
  ) {
    self.userID = userID
    self.email = email
    self.givenName = givenName
    self.familyName = familyName
    self.identityToken = identityToken
  }
}

/// Verified claims of an Apple identity token. `nonce` carries the
/// SHA-256 hex the client sent — the server checks the same value.
public struct AppleIDClaims: Sendable, Equatable {
  public let subject: String
  public let email: String?
  public let emailVerified: Bool
  public let nonce: String?
  public let audience: String
  public let issuer: String
  public let expiry: Date
  public init(
    subject: String, email: String?, emailVerified: Bool, nonce: String?, audience: String,
    issuer: String, expiry: Date
  ) {
    self.subject = subject
    self.email = email
    self.emailVerified = emailVerified
    self.nonce = nonce
    self.audience = audience
    self.issuer = issuer
    self.expiry = expiry
  }
}
