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

  /// Bundle identifier prefix for the app and its extensions.
  static let bundlePrefix = "app.runner"
}
