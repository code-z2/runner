//
//  MockCoachBrain.swift
//  RunnerPacePilotTesting
//
//  Created by Peter on 08/11/2026.
//

import RunnerPacePilot

/// Scripted brain: replays one queued answer per sample, then silence.
/// Lets scheduler tests control exactly when cues arrive.
public struct MockCoachBrain: CoachBrain, Sendable {

  public var state: CoachState

  private var queued: [CoachCue?]
  private var index = 0

  public init(queued: [CoachCue?] = [], state: CoachState = .steady) {
    self.state = state
    self.queued = queued
  }

  public mutating func advise(sample: CoachSample, context: CoachContext) -> CoachCue? {
    defer { index += 1 }
    guard index < queued.count else { return nil }
    return queued[index]
  }

  public mutating func openingCues() -> [CoachCue] {
    ["3", "2", "1"].map { CoachCue(kind: .countdown, text: $0, priority: .urgent) }
  }
}
