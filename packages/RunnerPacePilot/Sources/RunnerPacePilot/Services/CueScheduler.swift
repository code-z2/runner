//
//  CueScheduler.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// Quiet-by-default gate between brain and renderer. Routine cues are
/// spaced (the coach stays quiet most of the time); urgent cues —
/// countdown, endgame, completion, battery — bypass spacing. Anything
/// the preferences forbid is dropped and counted, never rendered.
public actor CueScheduler {

  /// Minimum gap between spoken routine cues.
  public static let routineSpacing: TimeInterval = 45

  private var brain: any CoachBrain
  private let renderer: any CueRenderer
  private let preferences: CoachPreferences
  private let beatTarget: Double?
  private let clock: @Sendable () -> Date

  private var lastRoutineRenderedAt: Date?
  public private(set) var droppedCount = 0

  public init(
    brain: any CoachBrain,
    renderer: any CueRenderer,
    preferences: CoachPreferences,
    beatTarget: Double? = nil,
    clock: @escaping @Sendable () -> Date = Date.init
  ) {
    self.brain = brain
    self.renderer = renderer
    self.preferences = preferences
    self.beatTarget = beatTarget
    self.clock = clock
  }

  /// Run start: speaks the 3-2-1 once. Silent when the coach is off.
  public func start(context: CoachContext) async {
    guard preferences.masterEnabled else { return }
    _ = context
    for cue in brain.openingCues() {
      await renderer.render(cue)
    }
    lastRoutineRenderedAt = clock()
  }

  /// One measured sample in. At most one cue out, plus a beat update.
  public func ingest(_ sample: CoachSample, context: CoachContext) async {
    guard preferences.masterEnabled else {
      droppedCount += 1
      return
    }
    let now = clock()
    if let cue = brain.advise(sample: sample, context: context) {
      if preferences.voiceEnabled, allows(cue, at: now) {
        await renderer.render(cue)
        if cue.priority == .routine {
          lastRoutineRenderedAt = now
        }
      } else {
        droppedCount += 1
      }
    }
    await updateBeats(sample: sample)
  }

  public func stopBeats() async {
    await renderer.setBeatInterval(nil)
  }

  private func allows(_ cue: CoachCue, at now: Date) -> Bool {
    guard cue.priority == .routine else { return true }
    guard let last = lastRoutineRenderedAt else { return true }
    return now.timeIntervalSince(last) >= Self.routineSpacing
  }

  private func updateBeats(sample: CoachSample) async {
    guard preferences.beatsEnabled, let target = beatTarget else {
      await renderer.setBeatInterval(nil)
      return
    }
    let interval = BeatPolicy(targetCadence: target).beatInterval(
      currentCadence: sample.cadence
    )
    await renderer.setBeatInterval(interval)
  }
}
