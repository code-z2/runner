//
//  MockHealthKitGateway.swift
//  RunnerHealthKitTesting
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerSession

@testable import RunnerHealthKit

/// Canned gateway. Single-threaded test use only.
public final class MockHealthKitGateway: HealthKitGateway, @unchecked Sendable {

  public var authorized: Bool

  public var heartRateSamples: [HeartRateSample]

  public private(set) var savedRuns: [(FinishedRunModel, Double?)] = []

  public init(authorized: Bool = true, heartRateSamples: [HeartRateSample] = []) {
    self.authorized = authorized
    self.heartRateSamples = heartRateSamples
  }

  public var canSaveWorkouts: Bool { authorized }

  public func requestAccess() async throws {
    guard authorized else {
      throw HealthKitError.notAuthorized
    }
  }

  public func saveRun(_ run: FinishedRunModel, distanceMeters: Double?) async throws {
    guard authorized else {
      throw HealthKitError.notAuthorized
    }
    savedRuns.append((run, distanceMeters))
  }

  public func readHeartRate(from start: Date, to end: Date) async throws -> [HeartRateSample] {
    guard authorized else {
      throw HealthKitError.notAuthorized
    }
    return heartRateSamples.filter { $0.timestamp >= start && $0.timestamp <= end }
  }

  public func liveHeartRate() -> AsyncStream<HeartRateEvent> {
    AsyncStream { continuation in
      continuation.yield(.unavailable)
      continuation.finish()
    }
  }
}
