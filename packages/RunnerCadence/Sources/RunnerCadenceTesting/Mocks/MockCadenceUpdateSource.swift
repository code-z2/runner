//
//  MockCadenceUpdateSource.swift
//  RunnerCadenceTesting
//
//  Created by Peter on 07/11/2026.
//

import RunnerCadence

/// Canned event source for tracker tests. Replays its events, then stops.
public final class MockCadenceUpdateSource: CadenceUpdateSource, @unchecked Sendable {

  private let events: [CadenceEvent]

  private var handler: (@Sendable (CadenceEvent) -> Void)?

  public init(events: [CadenceEvent]) {
    self.events = events
  }

  public func start(handler: @Sendable @escaping (CadenceEvent) -> Void) async throws {
    self.handler = handler
    for event in events {
      handler(event)
    }
  }

  public func stop() async {
    handler = nil
  }
}
