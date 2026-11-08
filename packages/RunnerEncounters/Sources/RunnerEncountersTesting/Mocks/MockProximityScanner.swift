//
//  MockProximityScanner.swift
//  RunnerEncountersTesting
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerEncounters

/// Replays canned sightings on start. Single-threaded test use only.
public final class MockProximityScanner: ProximityScanner, @unchecked Sendable {

  private let sightings: [ProximitySighting]

  public private(set) var startedCount = 0

  public private(set) var stoppedCount = 0

  public init(sightings: [ProximitySighting]) {
    self.sightings = sightings
  }

  public func start(handler: @Sendable @escaping (ProximitySighting) -> Void) async throws {
    startedCount += 1
    for sighting in sightings {
      handler(sighting)
    }
  }

  public func stop() async {
    stoppedCount += 1
  }
}
