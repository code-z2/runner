//
//  CadenceTrackerTests.swift
//  RunnerCadenceTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerCadenceTesting
import Testing

@testable import RunnerCadence

struct CadenceTrackerTests {

  @Test
  func startDeliversSourceEventsInOrder() async throws {
    let first = CadenceSampleModel(currentCadence: 1.5, timestamp: Date(timeIntervalSince1970: 1))
    let second = CadenceSampleModel(currentCadence: nil, timestamp: Date(timeIntervalSince1970: 2))
    let source = MockCadenceUpdateSource(events: [
      .sample(first),
      .unavailable,
      .sample(second),
    ])
    let tracker = CadenceTracker(source: source)

    let stream = try await tracker.start()

    var received: [CadenceEvent] = []
    for await event in stream {
      received.append(event)
      if received.count == 3 {
        break
      }
    }
    await tracker.stop()

    #expect(received == [.sample(first), .unavailable, .sample(second)])
  }

  @Test
  func doubleStartThrowsAlreadyActive() async throws {
    let tracker = CadenceTracker(source: MockCadenceUpdateSource(events: []))

    _ = try await tracker.start()

    await #expect(throws: CadenceError.alreadyActive) {
      try await tracker.start()
    }
  }

  @Test
  func stopEndsTheStream() async throws {
    let source = MockCadenceUpdateSource(events: [])
    let tracker = CadenceTracker(source: source)

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
    let sample = CadenceSampleModel(currentCadence: 1.5, timestamp: Date(timeIntervalSince1970: 1))
    let source = MockCadenceUpdateSource(events: [.sample(sample)])
    let tracker = CadenceTracker(source: source)

    let first = try await tracker.start()
    for await _ in first {
      break
    }
    await tracker.stop()

    let second = try await tracker.start()

    var received: [CadenceEvent] = []
    for await event in second {
      received.append(event)
      break
    }
    await tracker.stop()

    #expect(received == [.sample(sample)])
  }
}
