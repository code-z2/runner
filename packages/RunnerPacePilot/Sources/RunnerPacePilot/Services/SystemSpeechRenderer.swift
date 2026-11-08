//
//  SystemSpeechRenderer.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import AVFoundation
import Foundation

/// v1 voice backend: Apple speech synthesis, premium-first selection,
/// spoken through the app session so the ducking policy applies.
/// Personal Voice appears here automatically once the runner creates one
/// and opts in via `preferredVoiceID`. Compile-verified; voice behavior
/// is proven on-device (simulators lack downloadable premium voices).
public final class SystemSpeechRenderer: CueRenderer, @unchecked Sendable {

  // AVSpeechSynthesizer is main-thread bound; every use hops to MainActor,
  // which is what makes the unchecked conformance sound.
  private let synthesizer = AVSpeechSynthesizer()
  private let locale: Locale
  private let preferredVoiceID: String?

  public init(locale: Locale = .current, preferredVoiceID: String? = nil) {
    self.locale = locale
    self.preferredVoiceID = preferredVoiceID
  }

  public func render(_ cue: CoachCue) async {
    // Speech follows the app's audio session: the app layer applies
    // AudioSessionPolicy.voicePrompt around each cue so music ducks.
    let utterance = AVSpeechUtterance(string: cue.text)
    utterance.voice = platformVoice()
    let synthesizer = self.synthesizer
    await MainActor.run {
      synthesizer.speak(utterance)
    }
  }

  public func setBeatInterval(_ interval: TimeInterval?) async {
    // Beats ride a lightweight tick path owned by the app layer;
    // this backend only voices cues. A nil interval is a no-op here.
    _ = interval
  }

  private func platformVoice() -> AVSpeechSynthesisVoice? {
    let infos = AVSpeechSynthesisVoice.speechVoices().map {
      SpeechVoiceInfo(
        id: $0.identifier,
        name: $0.name,
        language: $0.language,
        quality: $0.quality == .premium ? .premium : $0.quality == .enhanced ? .enhanced : .compact
      )
    }
    guard
      let pick = SpeechVoiceSelector.pick(
        from: infos,
        locale: locale,
        preferredVoiceID: preferredVoiceID
      )
    else {
      return nil
    }
    return AVSpeechSynthesisVoice(identifier: pick.id)
  }
}
