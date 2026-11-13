//
//  CoachCue.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

/// One thing the coach wants to say. Produced by the brain, gated by
/// the scheduler, spoken by the renderer. Text is final — renderers
/// speak it verbatim and never embellish.
public struct CoachCue: Sendable, Equatable {

  public let kind: CueKind

  public let text: String

  public let priority: CuePriority

  public init(kind: CueKind, text: String, priority: CuePriority) {
    self.kind = kind
    self.text = text
    self.priority = priority
  }
}

public enum CueKind: String, Sendable, Equatable, Codable {

  case kilometer
  case endgame
  case complete
  case encouragement
  case praise
  case easeOff
  case stoppedNudge
  case batteryNudge
}

public enum CuePriority: Sendable, Equatable {

  /// Spaced by the scheduler's quiet policy.
  case routine

  /// Bypasses spacing: endgame, completion, battery.
  case urgent
}
