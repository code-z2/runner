//
//  BeatPolicy.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// Rhythmic tick-tock guidance at the target step interval. Beats play
/// while the runner drifts off their personal target and fade once
/// stable — re-entering only on fresh drift. Without measurement the
/// beats still guide open-loop at target; the scheduler fades them as
/// soon as measurement shows stability.
public struct BeatPolicy: Sendable, Equatable {

  /// Steps per minute. `nil` (no personal baseline yet) means no beats.
  public let targetCadence: Double?

  /// Cadences within this band of target read as stable: beats fade.
  public static let stableBand = 3.0

  public init(targetCadence: Double?) {
    self.targetCadence = targetCadence
  }

  /// Tick interval in seconds, or `nil` for silence.
  public func beatInterval(currentCadence: Double?) -> TimeInterval? {
    guard let target = targetCadence, target > 0 else { return nil }
    if let cadence = currentCadence,
      abs(cadence - target) <= Self.stableBand
    {
      return nil
    }
    return 60 / target
  }
}
