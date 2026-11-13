//
//  HealthKitGateway.swift
//  RunnerHealthKit
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerSession

/// The only seam through which the app touches HealthKit.
/// Write `workoutType`, read `heartRate` — nothing else without a new spec.
/// The live stream is designed for the Watch step; the phone
/// implementation honestly reports unavailable.
public protocol HealthKitGateway: Sendable {

  var canSaveWorkouts: Bool { get }

  func requestAccess() async throws

  @MainActor func startWorkoutSession(at date: Date) throws

  @MainActor func pauseWorkoutSession()

  @MainActor func resumeWorkoutSession()

  @MainActor func endWorkoutSession()

  func saveRun(_ run: FinishedRunModel, distanceMeters: Double?) async throws

  func readHeartRate(from start: Date, to end: Date) async throws -> [HeartRateSample]

  func liveHeartRate() -> AsyncStream<HeartRateEvent>
}

extension HealthKitGateway {
  @MainActor public func startWorkoutSession(at date: Date) throws {}
  @MainActor public func pauseWorkoutSession() {}
  @MainActor public func resumeWorkoutSession() {}
  @MainActor public func endWorkoutSession() {}
}
