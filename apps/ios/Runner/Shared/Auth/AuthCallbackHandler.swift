//
//  AuthCallbackHandler.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// Validates the universal-link auth callback and extracts the exchange
/// inputs. Host and path are allowlisted — anything else is not ours and
/// never reaches the coordinator.
struct AuthCallbackHandler: Sendable {

  let host: String

  let path: String

  /// Whether this URL is the auth callback at all. Guards `onOpenURL`.
  func isAuthCallback(_ url: URL) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.scheme == "https",
      components.host == host,
      components.path == path
    else { return false }
    return code(from: components) != nil
  }

  /// The authorization code and state. Throws when either is missing —
  /// the tenant always sends both on success.
  func code(from url: URL) throws -> (code: String, state: String) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      isAuthCallback(url),
      let code = code(from: components),
      let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
      !state.isEmpty
    else { throw AuthCallbackError.missingCode }
    return (code, state)
  }

  private func code(from components: URLComponents) -> String? {
    components.queryItems?.first(where: { $0.name == "code" })?.value
  }
}

enum AuthCallbackError: Sendable, Equatable, Error {

  case missingCode

  case stateMismatch
}
