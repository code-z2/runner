//
//  BeatPolicyTests.swift
//  RunnerPacePilotTests
//
//  Created by Peter on 08/11/2026.
//

import Foundation
import Testing

@testable import RunnerPacePilot

struct BeatPolicyTests {

  @Test
  func driftStartsBeatsAtTargetInterval() {
    let policy = BeatPolicy(targetCadence: 170)
    let interval = policy.beatInterval(currentCadence: 160)
    #expect(interval != nil)
    #expect(abs((interval ?? 0) - 60.0 / 170.0) < 0.0001)
  }

  @Test
  func stableCadenceFadesBeats() {
    let policy = BeatPolicy(targetCadence: 170)
    #expect(policy.beatInterval(currentCadence: 170) == nil)
    #expect(policy.beatInterval(currentCadence: 172) == nil)
    #expect(policy.beatInterval(currentCadence: 168) == nil)
  }

  @Test
  func noTargetNoBeats() {
    let policy = BeatPolicy(targetCadence: nil)
    #expect(policy.beatInterval(currentCadence: 150) == nil)
  }

  @Test
  func unknownCadenceKeepsOpenLoopBeats() {
    // Without measurement the beats still guide rhythm at target;
    // the scheduler fades them once measurement shows stability.
    let policy = BeatPolicy(targetCadence: 170)
    #expect(policy.beatInterval(currentCadence: nil) != nil)
  }

  @Test
  func optInDefaultsOff() {
    let prefs = CoachPreferences()
    #expect(prefs.masterEnabled == false)
    #expect(prefs.voiceEnabled == true)
    #expect(prefs.beatsEnabled == true)
  }
}
