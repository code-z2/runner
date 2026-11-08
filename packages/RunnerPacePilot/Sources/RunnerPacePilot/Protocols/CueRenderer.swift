//
//  CueRenderer.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// Speaks cues verbatim. Backends: `SystemSpeechRenderer` (Apple speech,
/// v1) and the named Kokoro-82M follow-up. Cloud TTS stays rejected —
/// see the package overview — but would also slot in here.
public protocol CueRenderer: Sendable {

  func render(_ cue: CoachCue) async

  /// `nil` silences beats. Ticks ride a lightweight path that never
  /// fights the voice session or the runner's music.
  func setBeatInterval(_ interval: TimeInterval?) async
}
