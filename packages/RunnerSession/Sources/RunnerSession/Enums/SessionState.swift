//
//  SessionState.swift
//  RunnerSession
//
//  Created by Peter on 07/11/2026.
//

/// The session lifecycle. Transitions are manual-only; see `WorkoutSession`.
public enum SessionState: Sendable, Equatable, Codable {

  case idle

  case active

  case paused

  case finished
}
