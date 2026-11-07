//
//  AppEnvironment.swift
//  Runner
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// The backend deployment the app talks to.
///
/// Resolution order (first match wins):
///   1. `RUNNER_ENV` in the process environment (scheme Run → Arguments).
///   2. `RunnerEnvironment` in `Info.plist`, injected from the `RUNNER_ENV`
///      build setting per build configuration.
///   3. Compile-time default: `.dev` for `DEBUG`, `.prod` otherwise.
nonisolated enum AppEnvironment: String, Sendable {

  case dev

  case staging

  case beta

  case prod

  /// The active environment, resolved once at launch.
  static let current: AppEnvironment = resolve()

  private static func resolve() -> AppEnvironment {
    if let raw = ProcessInfo.processInfo.environment["RUNNER_ENV"],
      let env = AppEnvironment(rawValue: raw.lowercased())
    {
      return env
    }
    if let raw = Bundle.main.object(forInfoDictionaryKey: "RunnerEnvironment") as? String,
      let env = AppEnvironment(rawValue: raw.lowercased())
    {
      return env
    }
    #if DEBUG
      return .dev
    #else
      return .prod
    #endif
  }

  /// The API root URL for this environment — no trailing slash, no version.
  var apiBaseURL: String {
    switch self {
    case .dev: return "http://localhost:8787"
    case .staging: return "https://staging-api.runner.app"
    case .beta: return "https://beta-api.runner.app"
    case .prod: return "https://api.runner.app"
    }
  }
}
