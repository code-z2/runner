//
//  LiveBatteryProvider.swift
//  RunnerSession
//
//  Created by Peter on 07/11/2026.
//

#if canImport(UIKit)
  import UIKit

  /// System battery level, or `nil` when unreadable. Monitoring is enabled
  /// lazily on first read; the app owns when that happens by holding this
  /// provider only for the session lifetime.
  public struct LiveBatteryProvider: Sendable {

    public init() {}

    @MainActor
    public func level() -> Float? {
      UIDevice.current.isBatteryMonitoringEnabled = true
      let level = UIDevice.current.batteryLevel
      return level >= 0 ? level : nil
    }
  }
#endif
