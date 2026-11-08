//
//  CoachSample.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// One measured snapshot offered to the brain. Unknowns stay `nil` —
/// the brain never synthesizes or clamps them.
///
/// Speeds are meters per second (matches `LocationSampleModel.speed`).
/// Faster means a larger number, so comparisons never invert pace.
public struct CoachSample: Sendable, Equatable {

  public let elapsed: TimeInterval

  public let distance: Double

  public let currentSpeed: Double?

  public let averageSpeed: Double?

  public let cadence: Double?

  public let heartRate: Double?

  public let batteryLevel: Float?

  public let plannedSegment: CoachSegment?

  public init(
    elapsed: TimeInterval,
    distance: Double,
    currentSpeed: Double?,
    averageSpeed: Double?,
    cadence: Double?,
    heartRate: Double?,
    batteryLevel: Float?,
    plannedSegment: CoachSegment?
  ) {
    self.elapsed = elapsed
    self.distance = distance
    self.currentSpeed = currentSpeed
    self.averageSpeed = averageSpeed
    self.cadence = cadence
    self.heartRate = heartRate
    self.batteryLevel = batteryLevel
    self.plannedSegment = plannedSegment
  }
}

/// A segment declared by a structured workout plan. `nil` (free run)
/// is the normal case; the brain never infers these from pace alone.
public enum CoachSegment: String, Sendable, Equatable, Codable {

  case interval
  case recovery
}
