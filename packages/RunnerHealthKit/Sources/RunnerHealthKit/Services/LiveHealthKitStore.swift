//
//  LiveHealthKitStore.swift
//  RunnerHealthKit
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import HealthKit
import RunnerSession

/// Live HealthKit boundary. Passive by design: workouts are saved after
/// the finish, heart rate is read for enrichment, and nothing here ever
/// joins the live loop. Authorization is requested, never assumed — HealthKit
/// denial degrades to unknown, never to missing runs.
///
/// All mutation happens on the caller's path (`requestAccess`, `saveRun`,
/// `readHeartRate`), never concurrently with shared state, which is why
/// `@unchecked Sendable` is sound here rather than a lock.
@available(macOS, unavailable, message: "Workout saving needs iOS HealthKit.")
public final class LiveHealthKitStore: HealthKitGateway, @unchecked Sendable {

  private let healthStore = HKHealthStore()

  @MainActor private var workoutSession: HKWorkoutSession?

  public init() {}

  @MainActor
  public func startWorkoutSession(at date: Date) throws {
    guard workoutSession == nil, canSaveWorkouts else { return }
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .running
    configuration.locationType = .outdoor
    let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
    workoutSession = session
    session.startActivity(with: date)
  }

  @MainActor public func pauseWorkoutSession() {
    workoutSession?.pause()
  }

  @MainActor public func resumeWorkoutSession() {
    workoutSession?.resume()
  }

  @MainActor public func endWorkoutSession() {
    workoutSession?.end()
    workoutSession = nil
  }

  public var canSaveWorkouts: Bool {
    HKHealthStore.isHealthDataAvailable()
      && healthStore.authorizationStatus(for: .workoutType()) == .sharingAuthorized
  }

  public func requestAccess() async throws {
    guard HKHealthStore.isHealthDataAvailable(),
      let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
    else {
      throw HealthKitError.unavailable
    }
    try await healthStore.requestAuthorization(
      toShare: [.workoutType(), distance],
      read: []
    )
    guard healthStore.authorizationStatus(for: .workoutType()) == .sharingAuthorized else {
      throw HealthKitError.notAuthorized
    }
  }

  public func saveRun(_ run: FinishedRunModel, distanceMeters: Double?) async throws {
    guard healthStore.authorizationStatus(for: .workoutType()) == .sharingAuthorized else {
      throw HealthKitError.notAuthorized
    }
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .running
    let builder = HKWorkoutBuilder(
      healthStore: healthStore,
      configuration: configuration,
      device: .local()
    )
    do {
      try await builder.beginCollection(at: run.startedAtWall)
      try await builder.addMetadata([
        HKMetadataKeySyncIdentifier: run.id.uuidString,
        HKMetadataKeySyncVersion: 1,
      ])
      let pauseEvents = run.pauses.flatMap { pause in
        [
          HKWorkoutEvent(
            type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil
          ),
          HKWorkoutEvent(
            type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil),
        ]
      }
      if !pauseEvents.isEmpty {
        try await builder.addWorkoutEvents(pauseEvents)
      }
      let activity = HKWorkoutActivity(
        workoutConfiguration: configuration,
        start: run.startedAtWall,
        end: run.finishedAtWall,
        metadata: nil
      )
      try await builder.addWorkoutActivity(activity)
      if let distanceMeters,
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
        healthStore.authorizationStatus(for: distanceType) == .sharingAuthorized
      {
        let quantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
        let sample = HKQuantitySample(
          type: distanceType,
          quantity: quantity,
          start: run.startedAtWall,
          end: run.finishedAtWall,
          metadata: [
            HKMetadataKeySyncIdentifier: "\(run.id.uuidString)-distance",
            HKMetadataKeySyncVersion: 1,
          ]
        )
        try await builder.addSamples([sample])
      }
      try await builder.endCollection(at: run.finishedAtWall)
      let _: HKWorkout = try await withCheckedThrowingContinuation { continuation in
        builder.finishWorkout { workout, error in
          if let error {
            continuation.resume(throwing: error)
          } else if let workout {
            continuation.resume(returning: workout)
          } else {
            continuation.resume(throwing: HealthKitError.saveFailed)
          }
        }
      }
    } catch let error as HealthKitError {
      throw error
    } catch {
      throw HealthKitError.saveFailed
    }
  }

  public func readHeartRate(from start: Date, to end: Date) async throws -> [HeartRateSample] {
    guard let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      throw HealthKitError.unavailable
    }
    return try await withCheckedThrowingContinuation { continuation in
      let predicate = HKQuery.predicateForSamples(
        withStart: start, end: end, options: .strictStartDate)
      let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
      let query = HKSampleQuery(
        sampleType: heartRate,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [sort]
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let readings = (samples as? [HKQuantitySample] ?? []).map {
          HeartRateSample(beatsPerMinute: $0.quantity.doubleValue(for: unit), timestamp: $0.endDate)
        }
        continuation.resume(returning: readings)
      }
      healthStore.execute(query)
    }
  }

  public func liveHeartRate() -> AsyncStream<HeartRateEvent> {
    AsyncStream { continuation in
      continuation.yield(.unavailable)
      continuation.finish()
    }
  }
}
