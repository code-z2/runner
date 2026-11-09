//
//  PersistedAccount.swift
//  RunnerAuth
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// The whole account in one atomic Keychain blob. Apple identity is
/// required; the server session and NEAR session attach as they arrive —
/// the app works without payments, so NEAR stays optional.
struct PersistedAccount: Sendable, Equatable, Codable {
  var appleUserID: String
  var email: String?
  var givenName: String?
  var familyName: String?
  var appleToken: String?
  var serverSession: String?
  var nearSubject: String?
  var nearAccountID: String?
  var nearPublicKey: String?
  var nearToken: String?
}
