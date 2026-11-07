//
//  MockLocationUpdateSource.swift
//  RunnerLocationTesting
//
//  Created by Peter on 07/11/2026.
//

import RunnerLocation

/// Canned event source for tracker tests. Replays its events, then stops.
public final class MockLocationUpdateSource: LocationUpdateSource, @unchecked Sendable {

    private let events: [LocationEvent]

    private var handler: (@Sendable (LocationEvent) -> Void)?

    public init(events: [LocationEvent]) {
        self.events = events
    }

    public func start(handler: @Sendable @escaping (LocationEvent) -> Void) {
        self.handler = handler
        for event in events {
            handler(event)
        }
    }

    public func stop() {
        handler = nil
    }
}
