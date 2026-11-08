//
//  HealthKitGatewayTests.swift
//  RunnerHealthKitTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerHealthKitTesting
import RunnerSession
import Testing

@testable import RunnerHealthKit

struct HealthKitGatewayTests {

  private func finishedRun() -> FinishedRunModel {
    FinishedRunModel(
      id: UUID(),
      startedAtWall: Date(timeIntervalSince1970: 1_000),
      activeElapsed: 600,
      finishedAtWall: Date(timeIntervalSince1970: 1_600),
      finishReason: .userFinished,
      batteryLevelAtStart: nil,
      batteryLevelAtEnd: nil
    )
  }

  @Test
  func saveRunRecordsThroughGateway() async throws {
    let gateway = MockHealthKitGateway()

    try await gateway.saveRun(finishedRun(), distanceMeters: 2_000)

    #expect(gateway.savedRuns.count == 1)
    #expect(gateway.savedRuns.first?.1 == 2_000)
  }

  @Test
  func unauthorizedSaveThrows() async {
    let gateway = MockHealthKitGateway(authorized: false)

    await #expect(throws: HealthKitError.notAuthorized) {
      try await gateway.saveRun(finishedRun(), distanceMeters: nil)
    }
  }

  @Test
  func heartRateReadsFilterToWindow() async throws {
    let samples = [
      HeartRateSample(beatsPerMinute: 120, timestamp: Date(timeIntervalSince1970: 1_100)),
      HeartRateSample(beatsPerMinute: 140, timestamp: Date(timeIntervalSince1970: 1_500)),
      HeartRateSample(beatsPerMinute: 90, timestamp: Date(timeIntervalSince1970: 2_000)),
    ]
    let gateway = MockHealthKitGateway(heartRateSamples: samples)

    let read = try await gateway.readHeartRate(
      from: Date(timeIntervalSince1970: 1_000),
      to: Date(timeIntervalSince1970: 1_600)
    )

    #expect(read.map(\.beatsPerMinute) == [120, 140])
  }

  @Test
  func unauthorizedReadThrows() async {
    let gateway = MockHealthKitGateway(authorized: false)

    await #expect(throws: HealthKitError.notAuthorized) {
      try await gateway.readHeartRate(from: Date(), to: Date())
    }
  }

  @Test
  func liveHeartRateIsUnavailableWithoutWatch() async {
    let gateway = MockHealthKitGateway()

    var received: [HeartRateEvent] = []
    for await event in gateway.liveHeartRate() {
      received.append(event)
    }

    #expect(received == [.unavailable])
  }
}
