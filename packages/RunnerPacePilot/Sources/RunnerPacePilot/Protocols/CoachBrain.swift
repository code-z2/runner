//
//  CoachBrain.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

/// The pluggable inference seam. v1 is `RulesCoachBrain` (deterministic,
/// on-device, no model). A Foundation Models adapter slots in later
/// behind this same protocol with a rules fallback; callers never change.
public protocol CoachBrain: Sendable {

  var state: CoachState { get }

  /// One sample in, at most one cue out. `nil` is the common case —
  /// the coach stays quiet unless something is worth saying.
  mutating func advise(sample: CoachSample, context: CoachContext) -> CoachCue?
}
