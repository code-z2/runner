//
//  MockCueRenderer.swift
//  RunnerPacePilotTesting
//
//  Created by Peter on 08/11/2026.
//

import Foundation
import RunnerPacePilot

/// Recording renderer: captures every cue and beat update for assertions.
public actor MockCueRenderer: CueRenderer {

  public private(set) var rendered: [CoachCue] = []
  public private(set) var beatIntervals: [TimeInterval?] = []

  public init() {}

  public func render(_ cue: CoachCue) async {
    rendered.append(cue)
  }

  public func setBeatInterval(_ interval: TimeInterval?) async {
    beatIntervals.append(interval)
  }
}
