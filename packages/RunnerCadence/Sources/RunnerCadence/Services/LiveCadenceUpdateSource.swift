//
//  LiveCadenceUpdateSource.swift
//  RunnerCadence
//
//  Created by Peter on 07/11/2026.
//

import CoreMotion
import Foundation

/// Live system cadence with fitness tuning. One shared pedometer per process:
/// several instances can perturb the delivery rate, so the tracker owns one.
///
/// Availability and authorization are injected so the guard logic is testable
/// without hardware. Pause-gap backfill belongs to the session layer, which
/// reconciles timelines with `queryPedometerData`.
///
/// All mutation happens on the tracker's call path: `start` then `stop`,
/// never concurrently. No shared state is touched from two threads, which is
/// why `@unchecked Sendable` is sound here rather than a lock.
@available(macOS, unavailable, message: "Cadence delivery needs device motion sensors.")
public final class LiveCadenceUpdateSource: CadenceUpdateSource, @unchecked Sendable {

  private let availabilityChecker: @Sendable () -> Bool

  private let authorizationChecker: @Sendable () -> CMAuthorizationStatus

  private var pedometer: CMPedometer?

  public init(
    availabilityChecker: @Sendable @escaping () -> Bool = CMPedometer.isCadenceAvailable,
    authorizationChecker: @Sendable @escaping () -> CMAuthorizationStatus = CMPedometer
      .authorizationStatus
  ) {
    self.availabilityChecker = availabilityChecker
    self.authorizationChecker = authorizationChecker
  }

  public func start(handler: @Sendable @escaping (CadenceEvent) -> Void) async throws {
    guard pedometer == nil else {
      return
    }
    let authorized: Bool
    switch authorizationChecker() {
    case .authorized:
      authorized = true
    case .denied, .restricted, .notDetermined:
      authorized = false
    @unknown default:
      authorized = false
    }
    guard CadenceStartPolicy.allowsStart(available: availabilityChecker(), authorized: authorized)
    else {
      throw CadenceError.unavailable
    }
    let pedometer = CMPedometer()
    self.pedometer = pedometer
    pedometer.startUpdates(from: Date()) { data, error in
      let events = CadenceEventMapper.events(
        currentCadence: data?.currentCadence,
        error: error,
        timestamp: data?.endDate ?? Date()
      )
      for event in events {
        handler(event)
      }
    }
  }

  public func stop() async {
    pedometer?.stopUpdates()
    pedometer = nil
  }
}
