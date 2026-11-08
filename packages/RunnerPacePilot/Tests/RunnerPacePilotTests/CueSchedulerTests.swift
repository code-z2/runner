//
//  CueSchedulerTests.swift
//  RunnerPacePilotTests
//
//  Created by Peter on 08/11/2026.
//

import Foundation
import RunnerPacePilotTesting
import Testing

@testable import RunnerPacePilot

struct CueSchedulerTests {

  private final class ClockBox: @unchecked Sendable {

    var now = Date(timeIntervalSince1970: 100_000)
  }

  private func sample(elapsed: TimeInterval = 400) -> CoachSample {
    CoachSample(
      elapsed: elapsed,
      distance: 1000,
      currentSpeed: 3.0,
      averageSpeed: 3.0,
      cadence: 170,
      heartRate: nil,
      batteryLevel: 0.9,
      plannedSegment: nil
    )
  }

  private func context() -> CoachContext {
    CoachContext(goalDistance: nil, cadenceBaseline: 170)
  }

  private func scheduler(
    brain: MockCoachBrain = MockCoachBrain(),
    renderer: MockCueRenderer = MockCueRenderer(),
    preferences: CoachPreferences = CoachPreferences(masterEnabled: true),
    box: ClockBox
  ) -> (CueScheduler, MockCueRenderer) {
    let scheduler = CueScheduler(
      brain: brain,
      renderer: renderer,
      preferences: preferences,
      clock: { box.now }
    )
    return (scheduler, renderer)
  }

  private func cue(_ kind: CueKind, priority: CuePriority = .routine) -> CoachCue {
    CoachCue(kind: kind, text: "test", priority: priority)
  }

  @Test
  func startRendersOpeningCues() async {
    let box = ClockBox()
    let (scheduler, renderer) = scheduler(box: box)
    await scheduler.start(context: context())
    let rendered = await renderer.rendered
    #expect(rendered.map(\.text) == ["3", "2", "1"])
  }

  @Test
  func quietByDefault() async {
    let box = ClockBox()
    let brain = MockCoachBrain(queued: [nil])
    let (scheduler, renderer) = scheduler(brain: brain, box: box)
    await scheduler.ingest(sample(), context: context())
    #expect(await renderer.rendered.isEmpty)
  }

  @Test
  func masterSwitchOffDropsEverything() async {
    let box = ClockBox()
    let brain = MockCoachBrain(queued: [cue(.kilometer)])
    let prefs = CoachPreferences(masterEnabled: false)
    let (scheduler, renderer) = scheduler(brain: brain, preferences: prefs, box: box)
    await scheduler.ingest(sample(), context: context())
    #expect(await renderer.rendered.isEmpty)
    #expect(await scheduler.droppedCount == 1)
  }

  @Test
  func voiceOffDropsVoiceCues() async {
    let box = ClockBox()
    let brain = MockCoachBrain(queued: [cue(.encouragement)])
    var prefs = CoachPreferences(masterEnabled: true)
    prefs.voiceEnabled = false
    let (scheduler, renderer) = scheduler(brain: brain, preferences: prefs, box: box)
    await scheduler.ingest(sample(), context: context())
    #expect(await renderer.rendered.isEmpty)
    #expect(await scheduler.droppedCount == 1)
  }

  @Test
  func routineCuesRespectSpacing() async {
    let box = ClockBox()
    let brain = MockCoachBrain(queued: [cue(.kilometer), cue(.encouragement)])
    let (scheduler, renderer) = scheduler(brain: brain, box: box)
    await scheduler.ingest(sample(), context: context())
    box.now = box.now.addingTimeInterval(10)
    await scheduler.ingest(sample(), context: context())
    #expect(await renderer.rendered.count == 1)
    #expect(await scheduler.droppedCount == 1)
  }

  @Test
  func urgentCuesBypassSpacing() async {
    let box = ClockBox()
    let brain = MockCoachBrain(queued: [cue(.kilometer), cue(.endgame, priority: .urgent)])
    let (scheduler, renderer) = scheduler(brain: brain, box: box)
    await scheduler.ingest(sample(), context: context())
    box.now = box.now.addingTimeInterval(10)
    await scheduler.ingest(sample(), context: context())
    #expect(await renderer.rendered.count == 2)
  }

  @Test
  func spacingResetsAfterInterval() async {
    let box = ClockBox()
    let brain = MockCoachBrain(queued: [cue(.kilometer), cue(.encouragement)])
    let (scheduler, renderer) = scheduler(brain: brain, box: box)
    await scheduler.ingest(sample(), context: context())
    box.now = box.now.addingTimeInterval(60)
    await scheduler.ingest(sample(), context: context())
    #expect(await renderer.rendered.count == 2)
  }

  @Test
  func beatsFollowDriftAndFadeWhenStable() async {
    let box = ClockBox()
    let renderer = MockCueRenderer()
    let beating = CueScheduler(
      brain: MockCoachBrain(queued: [nil, nil]),
      renderer: renderer,
      preferences: CoachPreferences(masterEnabled: true),
      beatTarget: 170,
      clock: { box.now }
    )
    // Drifting cadence: beats on.
    let drifting = CoachSample(
      elapsed: 400, distance: 1000, currentSpeed: 3.0, averageSpeed: 3.0,
      cadence: 160, heartRate: nil, batteryLevel: 0.9, plannedSegment: nil
    )
    await beating.ingest(drifting, context: context())
    // Stable cadence: beats fade.
    let stable = CoachSample(
      elapsed: 460, distance: 1200, currentSpeed: 3.0, averageSpeed: 3.0,
      cadence: 170, heartRate: nil, batteryLevel: 0.9, plannedSegment: nil
    )
    await beating.ingest(stable, context: context())
    let beats = await renderer.beatIntervals
    #expect(beats.count == 2)
    #expect(beats[0] != nil)
    #expect(beats[1] == nil)
  }
}
