//
//  RunnerPacePilot.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

/// Live running coach: deterministic rules brain behind a pluggable seam,
/// a quiet-by-default cue scheduler, and a speech renderer.
///
/// Agreed spec: `design/ORDER.md` §6 (A01/A03/A04/A05/A06) plus the
/// voice/audio/opt-in research: Apple speech first (premium-first,
/// Personal Voice opt-in), Kokoro-82M on-device neural voice as the
/// named follow-up backend, cloud TTS rejected. Music ducks per cue,
/// never stops. Coach ships off; arming is explicit and persisted by
/// the app layer.
public enum RunnerPacePilot {}
