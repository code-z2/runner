//
//  LocationTrackerTests.swift
//  RunnerLocationTests
//
//  Created by Peter on 07/11/2026.
//

import Testing

@testable import RunnerLocation
import RunnerLocationTesting

struct LocationTrackerTests {

    @Test
    func startDeliversSourceEventsInOrder() async throws {
        let source = MockLocationUpdateSource(events: [
            .stationary,
            .accuracyReduced,
            .locationUnavailable,
        ])
        let tracker = LocationTracker(source: source)

        let stream = try await tracker.start()

        var received: [LocationEvent] = []
        for await event in stream {
            received.append(event)
            if received.count == 3 {
                break
            }
        }
        await tracker.stop()

        #expect(received == [.stationary, .accuracyReduced, .locationUnavailable])
    }

    @Test
    func doubleStartThrowsAlreadyActive() async throws {
        let tracker = LocationTracker(source: MockLocationUpdateSource(events: []))

        _ = try await tracker.start()

        await #expect(throws: LocationError.alreadyActive) {
            try await tracker.start()
        }
    }

    @Test
    func stopEndsTheStream() async throws {
        let source = MockLocationUpdateSource(events: [])
        let tracker = LocationTracker(source: source)

        let stream = try await tracker.start()
        await tracker.stop()

        var count = 0
        for await _ in stream {
            count += 1
        }

        #expect(count == 0)
        #expect(await tracker.isActive == false)
    }

    @Test
    func restartAfterStopDeliversAgain() async throws {
        let source = MockLocationUpdateSource(events: [.stationary])
        let tracker = LocationTracker(source: source)

        let first = try await tracker.start()
        for await _ in first {
            break
        }
        await tracker.stop()

        let second = try await tracker.start()

        var received: [LocationEvent] = []
        for await event in second {
            received.append(event)
            break
        }
        await tracker.stop()

        #expect(received == [.stationary])
    }
}
