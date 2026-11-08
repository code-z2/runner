//
//  EncounterHaptics.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

/// The graded buzz. The live implementation owns the feedback generator;
/// the policy of when to buzz lives in `RssiGrader`, not here.
public protocol EncounterHaptics: Sendable {

  func buzz(_ intensity: BuzzIntensity)
}
