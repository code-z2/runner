//
//  CoachState.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

/// The coach's model of what the runner is doing right now.
///
/// Every case except `interval` is derived from measured samples.
/// `interval` is entered only when a structured workout plan declares
/// the segment — the brain never invents intervals from raw pace.
public enum CoachState: String, Sendable, Equatable, Codable, CaseIterable {

  case idle
  case warmUp
  case steady
  case accelerating
  case interval
  case recovery
  case cooldown
}
