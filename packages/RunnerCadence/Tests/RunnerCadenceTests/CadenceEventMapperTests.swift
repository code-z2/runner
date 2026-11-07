//
//  CadenceEventMapperTests.swift
//  RunnerCadenceTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import Testing

@testable import RunnerCadence

struct CadenceEventMapperTests {

  @Test
  func reportedCadenceYieldsOneSample() {
    let events = CadenceEventMapper.events(
      currentCadence: 1.5,
      error: nil,
      timestamp: Date(timeIntervalSince1970: 100)
    )

    #expect(events.count == 1)
    if case .sample(let sample) = events.first {
      #expect(sample.stepsPerSecond == 1.5)
    } else {
      Issue.record("Expected a sample event")
    }
  }

  @Test
  func missingCadenceYieldsUnknownSample() {
    let events = CadenceEventMapper.events(
      currentCadence: nil,
      error: nil,
      timestamp: Date(timeIntervalSince1970: 100)
    )

    #expect(events.count == 1)
    if case .sample(let sample) = events.first {
      #expect(sample.stepsPerSecond == nil)
    } else {
      Issue.record("Expected a sample event")
    }
  }

  @Test
  func handlerErrorYieldsUnavailable() {
    struct SensorFailure: Error {}

    let events = CadenceEventMapper.events(
      currentCadence: 1.5,
      error: SensorFailure(),
      timestamp: Date()
    )

    #expect(events == [.unavailable])
  }
}
