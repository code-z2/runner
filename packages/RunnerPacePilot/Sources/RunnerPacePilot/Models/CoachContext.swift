//
//  CoachContext.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// Slow-moving run context: the goal being chased and the runner's own
/// baseline. Both optional — the coach works without either.
public struct CoachContext: Sendable, Equatable {

  /// Meters. Set for K-goal runs; drives kilometer calls and endgame marks.
  public let goalDistance: Double?

  /// Steps per minute measured from the runner's own history.
  /// Never a fixed 180 — targets are personal or absent.
  public let cadenceBaseline: Double?

  public init(goalDistance: Double?, cadenceBaseline: Double?) {
    self.goalDistance = goalDistance
    self.cadenceBaseline = cadenceBaseline
  }
}
