//
//  CadenceSampleModelTests.swift
//  RunnerCadenceTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import Testing

@testable import RunnerCadence

struct CadenceSampleModelTests {

  @Test(arguments: [
    (currentCadence: 1.5 as NSNumber?, expected: 1.5),
    (currentCadence: 0.0 as NSNumber?, expected: 0.0),
  ])
  func reportedCadencePassesThrough(currentCadence: NSNumber?, expected: Double?) {
    let sample = CadenceSampleModel(
      currentCadence: currentCadence,
      timestamp: Date(timeIntervalSince1970: 100)
    )

    #expect(sample.stepsPerSecond == expected)
  }

  @Test
  func missingCadenceReadsAsUnknown() {
    let sample = CadenceSampleModel(
      currentCadence: nil,
      timestamp: Date(timeIntervalSince1970: 100)
    )

    #expect(sample.stepsPerSecond == nil)
  }

  @Test
  func timestampPassesThrough() {
    let timestamp = Date(timeIntervalSince1970: 200)

    let sample = CadenceSampleModel(
      currentCadence: 2.0,
      timestamp: timestamp
    )

    #expect(sample.timestamp == timestamp)
  }
}
