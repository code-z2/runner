//
//  MockProximityAdvertiser.swift
//  RunnerEncountersTesting
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerEncounters

/// Records lifecycle calls. Single-threaded test use only.
public final class MockProximityAdvertiser: ProximityAdvertiser, @unchecked Sendable {

  public private(set) var startedCount = 0

  public private(set) var stoppedCount = 0

  public private(set) var refreshedCount = 0

  public init() {}

  public func start() async throws {
    startedCount += 1
  }

  public func stop() async {
    stoppedCount += 1
  }

  public func refreshIdentity() async {
    refreshedCount += 1
  }
}
