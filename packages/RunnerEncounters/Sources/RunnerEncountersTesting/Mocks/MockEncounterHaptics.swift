//
//  MockEncounterHaptics.swift
//  RunnerEncountersTesting
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerEncounters

/// Records requested buzzes. Single-threaded test use only.
public final class MockEncounterHaptics: EncounterHaptics, @unchecked Sendable {

  public private(set) var buzzed: [BuzzIntensity] = []

  public init() {}

  public func buzz(_ intensity: BuzzIntensity) {
    buzzed.append(intensity)
  }
}
