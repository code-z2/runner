//
//  RulesCoachBrain.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// Deterministic v1 brain. Encouragement fires only on computed evidence
/// (running faster than own average with cadence near personal baseline),
/// praise only on compliance, ease-off on struggle with a back-off window.
/// Suggestive tone throughout — the coach never orders, never pressures.
public struct RulesCoachBrain: CoachBrain, Sendable {

  public private(set) var state: CoachState = .idle

  private var opened = false
  private var lastKilometer = 0
  private var previousRemaining: Double?
  private var emittedEndgame: Set<Int> = []
  private var emittedComplete = false
  private var recentSpeeds: [Double] = []

  private var encouragementElapsed: TimeInterval?
  private var encouragementSpeed: Double?
  private var lastEncouragementElapsed: TimeInterval?
  private var backoffUntilElapsed: TimeInterval?

  private var stoppedSinceElapsed: TimeInterval?
  private var stoppedNudged = false
  private var batteryNudged = false

  // MARK: - Tuning (all documented, none hidden)

  /// First N seconds of a run read as warm-up.
  private static let warmUpLength: TimeInterval = 300
  /// Earliest encouragement: no coaching inside the first 2 minutes.
  private static let encouragementFloor: TimeInterval = 120
  /// "Faster" bar for both trend and encouragement evidence.
  private static let fasterFactor = 1.03
  /// Struggle bar relative to own average.
  private static let struggleFactor = 0.95
  /// Quiet gap between encouragement attempts.
  private static let encouragementSpacing: TimeInterval = 180
  /// Compliance watch expires silently after this.
  private static let complianceWindow: TimeInterval = 120
  /// Compliance counts once the push has held this long.
  private static let complianceHold: TimeInterval = 15
  /// Ease-off suppresses further encouragement for this long.
  private static let backoffLength: TimeInterval = 300
  /// Valid speed below this reads as stationary (not "unknown").
  private static let stationarySpeed = 0.3
  /// Stillness sustained this long triggers one stopped nudge.
  private static let stoppedAfter: TimeInterval = 30
  /// Battery fraction that triggers one low-battery nudge.
  private static let lowBattery: Float = 0.2

  /// Endgame marks in meters remaining, exact sequence per spec.
  private static let endgameMarks = [400, 300, 200, 100, 50]
  /// Inside the final 400 m the run reads as cooldown.
  private static let cooldownInside = 400.0

  public init() {}

  public mutating func openingCues() -> [CoachCue] {
    guard !opened else { return [] }
    opened = true
    return ["3", "2", "1"].map { CoachCue(kind: .countdown, text: $0, priority: .urgent) }
  }

  public mutating func advise(sample: CoachSample, context: CoachContext) -> CoachCue? {
    updateState(sample: sample, context: context)
    trackSpeed(sample.currentSpeed)

    // Priority order: countdown is handled by openingCues; here
    // battery > completion/endgame > stopped > kilometer > adaptive.
    if let cue = batteryCue(sample: sample) { return cue }
    if let cue = goalCue(sample: sample, context: context) { return cue }
    if let cue = stoppedCue(sample: sample) { return cue }
    if let cue = kilometerCue(sample: sample) { return cue }
    return adaptiveCue(sample: sample, context: context)
  }

  // MARK: - State

  private mutating func updateState(sample: CoachSample, context: CoachContext) {
    if sample.plannedSegment == .interval {
      state = .interval
      return
    }
    if let goal = context.goalDistance, goal - sample.distance <= Self.cooldownInside {
      state = .cooldown
      return
    }
    if sample.elapsed < Self.warmUpLength {
      state = .warmUp
      return
    }
    let recent = recentSpeeds.suffix(3)
    if recent.count >= 2, let average = sample.averageSpeed, average > 0 {
      let mean = recent.reduce(0, +) / Double(recent.count)
      if mean > average * Self.fasterFactor {
        state = .accelerating
        return
      }
      if mean < average * Self.struggleFactor {
        state = .recovery
        return
      }
    }
    state = .steady
  }

  private mutating func trackSpeed(_ speed: Double?) {
    guard let speed, speed >= 0 else { return }
    recentSpeeds.append(speed)
    if recentSpeeds.count > 6 { recentSpeeds.removeFirst() }
  }

  // MARK: - Cues

  private mutating func batteryCue(sample: CoachSample) -> CoachCue? {
    guard !batteryNudged, let level = sample.batteryLevel, level < Self.lowBattery else {
      return nil
    }
    batteryNudged = true
    let percent = Int((level * 100).rounded())
    return CoachCue(
      kind: .batteryNudge,
      text: "Battery is low at \(percent) percent.",
      priority: .urgent
    )
  }

  private mutating func goalCue(sample: CoachSample, context: CoachContext) -> CoachCue? {
    guard let goal = context.goalDistance, goal > 0 else { return nil }
    let remaining = goal - sample.distance
    defer { previousRemaining = remaining }
    if remaining <= 0, !emittedComplete {
      emittedComplete = true
      return CoachCue(kind: .complete, text: "Goal complete.", priority: .urgent)
    }
    guard let previous = previousRemaining else { return nil }
    for mark in Self.endgameMarks where !emittedEndgame.contains(mark) {
      if previous > Double(mark), remaining <= Double(mark) {
        emittedEndgame.insert(mark)
        return CoachCue(
          kind: .endgame,
          text: "\(mark) meters to go.",
          priority: .urgent
        )
      }
    }
    return nil
  }

  private mutating func stoppedCue(sample: CoachSample) -> CoachCue? {
    // Unknown speed is never evidence of stopping — only a valid
    // near-zero speed sustained over time counts.
    guard let speed = sample.currentSpeed, speed >= 0 else {
      stoppedSinceElapsed = nil
      return nil
    }
    guard speed < Self.stationarySpeed else {
      stoppedSinceElapsed = nil
      stoppedNudged = false
      return nil
    }
    if stoppedSinceElapsed == nil { stoppedSinceElapsed = sample.elapsed }
    guard !stoppedNudged,
      sample.elapsed - (stoppedSinceElapsed ?? sample.elapsed) >= Self.stoppedAfter
    else {
      return nil
    }
    stoppedNudged = true
    return CoachCue(
      kind: .stoppedNudge,
      text: "Looks like you've stopped. Pause the run when you're ready.",
      priority: .routine
    )
  }

  private mutating func kilometerCue(sample: CoachSample) -> CoachCue? {
    let kilometer = Int(sample.distance / 1000)
    guard kilometer > lastKilometer else { return nil }
    lastKilometer = kilometer
    var text = "Kilometer \(kilometer)."
    let pace = Self.paceString(speedMetersPerSecond: sample.averageSpeed)
    if pace != "unknown pace" { text += " \(pace)." }
    return CoachCue(kind: .kilometer, text: text, priority: .routine)
  }

  private mutating func adaptiveCue(sample: CoachSample, context: CoachContext) -> CoachCue? {
    if let cue = complianceCue(sample: sample) { return cue }
    guard sample.elapsed >= Self.encouragementFloor,
      let current = sample.currentSpeed, current > 0,
      let average = sample.averageSpeed, average > 0,
      current > average * Self.fasterFactor,
      !inBackoff(elapsed: sample.elapsed),
      spacedOut(elapsed: sample.elapsed)
    else {
      return nil
    }
    if let baseline = context.cadenceBaseline, baseline > 0,
      let cadence = sample.cadence, cadence < baseline * 0.9
    {
      return nil
    }
    encouragementElapsed = sample.elapsed
    encouragementSpeed = current
    lastEncouragementElapsed = sample.elapsed
    return CoachCue(
      kind: .encouragement,
      text: "Based on your activity, you could run a little faster.",
      priority: .routine
    )
  }

  private mutating func complianceCue(sample: CoachSample) -> CoachCue? {
    guard let since = encouragementElapsed,
      let pushed = encouragementSpeed,
      let average = sample.averageSpeed
    else {
      return nil
    }
    if sample.elapsed - since > Self.complianceWindow {
      encouragementElapsed = nil
      encouragementSpeed = nil
      return nil
    }
    guard let current = sample.currentSpeed else { return nil }
    if sample.elapsed - since >= Self.complianceHold, current >= pushed {
      encouragementElapsed = nil
      encouragementSpeed = nil
      return CoachCue(
        kind: .praise,
        text: "Great, hold it there. Don't push too hard.",
        priority: .routine
      )
    }
    if current < average * Self.struggleFactor {
      encouragementElapsed = nil
      encouragementSpeed = nil
      backoffUntilElapsed = sample.elapsed + Self.backoffLength
      return CoachCue(
        kind: .easeOff,
        text: "Ease off a touch, no pressure.",
        priority: .routine
      )
    }
    return nil
  }

  private func inBackoff(elapsed: TimeInterval) -> Bool {
    guard let until = backoffUntilElapsed else { return false }
    return elapsed < until
  }

  private func spacedOut(elapsed: TimeInterval) -> Bool {
    guard let last = lastEncouragementElapsed else { return true }
    return elapsed - last >= Self.encouragementSpacing
  }

  // MARK: - Formatting

  static func paceString(speedMetersPerSecond: Double?) -> String {
    guard let speed = speedMetersPerSecond, speed > 0 else { return "unknown pace" }
    let secondsPerKm = Int((1000 / speed).rounded())
    return "\(secondsPerKm / 60):\(String(format: "%02d", secondsPerKm % 60))/km"
  }
}
