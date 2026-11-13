//
//  RulesCoachBrainTests.swift
//  RunnerPacePilotTests
//
//  Created by Peter on 08/11/2026.
//

import Foundation
import Testing

@testable import RunnerPacePilot

struct RulesCoachBrainTests {

  private func sample(
    elapsed: TimeInterval = 400,
    distance: Double = 500,
    currentSpeed: Double? = 3.0,
    averageSpeed: Double? = 3.0,
    cadence: Double? = 170,
    batteryLevel: Float? = 0.9
  ) -> CoachSample {
    CoachSample(
      elapsed: elapsed,
      distance: distance,
      currentSpeed: currentSpeed,
      averageSpeed: averageSpeed,
      cadence: cadence,
      heartRate: nil,
      batteryLevel: batteryLevel,
      plannedSegment: nil
    )
  }

  private func context(
    goalDistance: Double? = nil,
    cadenceBaseline: Double? = 170
  ) -> CoachContext {
    CoachContext(goalDistance: goalDistance, cadenceBaseline: cadenceBaseline)
  }

  @Test
  func steadyMilesProduceKilometerMarks() {
    var brain = RulesCoachBrain()
    let first = brain.advise(sample: sample(distance: 1001), context: context())
    #expect(first?.kind == .kilometer)
    #expect(first?.text.contains("Kilometer one") == true)
    // Same kilometer again stays quiet.
    let secondCue = brain.advise(sample: sample(distance: 1501), context: context())
    #expect(secondCue == nil)
    let second = brain.advise(sample: sample(distance: 2001), context: context())
    #expect(second?.kind == .kilometer)
    #expect(second?.text.contains("Kilometer two") == true)
  }

  @Test
  func kilometerCueSpellsOutNumberAndPace() {
    var brain = RulesCoachBrain()
    let cue = brain.advise(
      sample: sample(distance: 1001, averageSpeed: 1000 / 380),
      context: context()
    )
    #expect(
      cue?.text
        == "Kilometer one. Your average pace is six minutes and twenty seconds per kilometer."
    )
  }

  @Test
  func spokenPaceHandlesSingularsAndUnknown() {
    #expect(
      RulesCoachBrain.spokenPaceString(speedMetersPerSecond: 1000 / 61)
        == "Your average pace is one minute and one second per kilometer")
    #expect(RulesCoachBrain.spokenPaceString(speedMetersPerSecond: nil) == nil)
    #expect(RulesCoachBrain.spokenPaceString(speedMetersPerSecond: 0) == nil)
  }

  @Test
  func spelledOutNumbersArePlainWords() {
    #expect(SpelledOutNumber.words(42) == "forty two")
    #expect(SpelledOutNumber.words(1) == "one")
    #expect(SpelledOutNumber.capitalizedWords(400) == "Four hundred")
    #expect(SpelledOutNumber.pace(minutes: 5, seconds: 33) == "five minutes and thirty three seconds")
  }

  @Test
  func encouragementNeedsComputedEvidence() {
    var brain = RulesCoachBrain()
    // Faster than average with cadence near baseline: evidence.
    let cue = brain.advise(
      sample: sample(currentSpeed: 3.2, averageSpeed: 3.0, cadence: 168),
      context: context()
    )
    #expect(cue?.kind == .encouragement)
    #expect(cue?.priority == .routine)
  }

  @Test
  func noEncouragementWithoutEvidence() {
    var brain = RulesCoachBrain()
    // Slower than average: no evidence, stays quiet.
    let cue = brain.advise(
      sample: sample(currentSpeed: 2.8, averageSpeed: 3.0),
      context: context()
    )
    #expect(cue == nil)
  }

  @Test
  func noEncouragementOnUnknownSpeed() {
    var brain = RulesCoachBrain()
    let cue = brain.advise(
      sample: sample(currentSpeed: nil, averageSpeed: 3.0),
      context: context()
    )
    #expect(cue == nil)
  }

  @Test
  func praiseOnCompliance() {
    var brain = RulesCoachBrain()
    _ = brain.advise(
      sample: sample(elapsed: 400, currentSpeed: 3.2, averageSpeed: 3.0),
      context: context()
    )
    let praise = brain.advise(
      sample: sample(elapsed: 430, currentSpeed: 3.25, averageSpeed: 3.0),
      context: context()
    )
    #expect(praise?.kind == .praise)
  }

  @Test
  func easeOffOnStruggleThenBackOff() {
    var brain = RulesCoachBrain()
    _ = brain.advise(
      sample: sample(elapsed: 400, currentSpeed: 3.2, averageSpeed: 3.0),
      context: context()
    )
    let ease = brain.advise(
      sample: sample(elapsed: 430, currentSpeed: 2.7, averageSpeed: 3.0),
      context: context()
    )
    #expect(ease?.kind == .easeOff)
    // Fresh evidence inside the back-off window still stays quiet.
    let nagged = brain.advise(
      sample: sample(elapsed: 500, currentSpeed: 3.3, averageSpeed: 3.0),
      context: context()
    )
    #expect(nagged == nil)
  }

  @Test
  func endgameMarksFireInOrder() {
    var brain = RulesCoachBrain()
    let ctx = context(goalDistance: 5000)
    var kinds: [CueKind] = []
    for distance in [4400.0, 4600, 4650, 4700, 4800, 4900, 4950, 5000] {
      if let cue = brain.advise(sample: sample(distance: distance), context: ctx) {
        kinds.append(cue.kind)
      }
    }
    #expect(kinds.contains(.endgame))
    #expect(kinds.last == .complete)
  }

  @Test
  func endgameTextNamesRemaining() {
    var brain = RulesCoachBrain()
    let ctx = context(goalDistance: 5000)
    _ = brain.advise(sample: sample(distance: 4400), context: ctx)
    let cue = brain.advise(sample: sample(distance: 4600), context: ctx)
    #expect(cue?.kind == .endgame)
    #expect(cue?.text.contains("Four hundred") == true)
    #expect(cue?.priority == .urgent)
  }

  @Test
  func stoppedNudgeIsPromptOnlyAndOnce() {
    var brain = RulesCoachBrain()
    var kinds: [CueKind] = []
    var elapsed: TimeInterval = 400
    for _ in 0..<8 {
      if let cue = brain.advise(
        sample: sample(elapsed: elapsed, distance: 1000, currentSpeed: 0),
        context: context()
      ) {
        kinds.append(cue.kind)
      }
      elapsed += 10
    }
    #expect(kinds.filter({ $0 == .stoppedNudge }).count == 1)
    // Still stopped: no repeat nag.
    let secondCue = brain.advise(
      sample: sample(elapsed: elapsed, distance: 1000, currentSpeed: 0),
      context: context()
    )
    #expect(secondCue == nil)
  }

  @Test
  func unknownSpeedNeverCountsAsStopped() {
    var brain = RulesCoachBrain()
    var cue: CoachCue?
    for i in 0..<10 {
      cue = brain.advise(
        sample: sample(elapsed: 400 + Double(i) * 10, currentSpeed: nil),
        context: context()
      )
    }
    #expect(cue == nil)
  }

  @Test
  func batteryNudgeFiresOnce() {
    var brain = RulesCoachBrain()
    let first = brain.advise(sample: sample(batteryLevel: 0.15), context: context())
    #expect(first?.kind == .batteryNudge)
    let second = brain.advise(sample: sample(batteryLevel: 0.10), context: context())
    #expect(second == nil)
  }

  @Test
  func stateDerivation() {
    // Low cadence throughout blocks encouragement so only state is exercised.
    var brain = RulesCoachBrain()
    _ = brain.advise(sample: sample(elapsed: 60, cadence: 140), context: context())
    #expect(brain.state == .warmUp)
    _ = brain.advise(
      sample: sample(elapsed: 300, currentSpeed: 3.0, cadence: 140), context: context())
    _ = brain.advise(
      sample: sample(elapsed: 310, currentSpeed: 3.3, cadence: 140), context: context())
    _ = brain.advise(
      sample: sample(elapsed: 320, currentSpeed: 3.3, cadence: 140), context: context())
    #expect(brain.state == .accelerating)
    _ = brain.advise(
      sample: sample(elapsed: 330, currentSpeed: 2.6, cadence: 140), context: context())
    _ = brain.advise(
      sample: sample(elapsed: 340, currentSpeed: 2.6, cadence: 140), context: context())
    _ = brain.advise(
      sample: sample(elapsed: 350, currentSpeed: 2.6, cadence: 140), context: context())
    #expect(brain.state == .recovery)
  }

  @Test
  func intervalStateOnlyFromPlan() {
    var brain = RulesCoachBrain()
    var planned = sample(elapsed: 400)
    planned = CoachSample(
      elapsed: 400,
      distance: 1000,
      currentSpeed: 4.0,
      averageSpeed: 3.0,
      cadence: 180,
      heartRate: nil,
      batteryLevel: 0.9,
      plannedSegment: .interval
    )
    _ = brain.advise(sample: planned, context: context())
    #expect(brain.state == .interval)
  }

  @Test
  func paceFormatting() {
    #expect(RulesCoachBrain.paceString(speedMetersPerSecond: 3.0) == "5:33/km")
    #expect(RulesCoachBrain.paceString(speedMetersPerSecond: nil) == "unknown pace")
    #expect(RulesCoachBrain.paceString(speedMetersPerSecond: 0) == "unknown pace")
  }
}
