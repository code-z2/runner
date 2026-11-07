//
//  ManualClock.swift
//  RunnerSessionTesting
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// Deterministic monotonic clock for tests. Single-threaded test use only.
public final class ManualClock: @unchecked Sendable {

  public var now: TimeInterval

  public init(now: TimeInterval = 1_000) {
    self.now = now
  }

  public func advance(by interval: TimeInterval) {
    now += interval
  }
}
