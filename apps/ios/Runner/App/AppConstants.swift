//
//  AppConstants.swift
//  Runner
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// Build-wide constants. Feature constants live with their feature.
nonisolated enum AppConstants {
  /// API version appended downstream of `AppEnvironment.apiBaseURL`.
  static let apiVersion = "v1"

  /// Apple audience for the native auth flow: the app's bundle ID.
  static let bundlePrefix = "io.wades.ije"

  /// Associated domain host for HTTPS callbacks and universal links.
  /// Served with the `apple-app-site-association` file; every URL under
  /// it that is not an allowlisted app route stays in Safari.
  static let associatedDomain = "ije.wades.io"

  /// Callback path on the associated domain.
  static let authCallbackPath = "/auth/callback"

  /// The full redirect URI handed to Auth0. HTTPS only, per the iOS 17.4+
  /// session API — no custom scheme anywhere in the product.
  static var authCallbackURL: URL {
    URL(string: "https://\(associatedDomain)\(authCallbackPath)")!
  }

  /// The NEP-366 delegate endpoint behind `RunnerGatewayClient.relay(_:)`.
  static var nearRelayURL: URL {
    URL(string: AppEnvironment.current.apiBaseURL + "/v1/relay")!
  }
}
