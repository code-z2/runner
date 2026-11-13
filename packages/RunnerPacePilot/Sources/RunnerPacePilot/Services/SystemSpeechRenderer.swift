//
//  SystemSpeechRenderer.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import AVFoundation
import Foundation

/// Apple speech backend. A render completes when playback ends.
@MainActor
public final class SystemSpeechRenderer: NSObject, CueRenderer, AVSpeechSynthesizerDelegate {

  private let synthesizer = AVSpeechSynthesizer()
  private var playback: CheckedContinuation<Void, Never>?
  private var utteranceID: ObjectIdentifier?
  private let locale: Locale
  private let preferredVoiceID: String?

  public init(locale: Locale = .current, preferredVoiceID: String? = nil) {
    self.locale = locale
    self.preferredVoiceID = preferredVoiceID
    super.init()
    synthesizer.delegate = self
    #if os(iOS)
      synthesizer.usesApplicationAudioSession = false
    #endif
  }

  public func render(_ cue: CoachCue) async {
    guard !Task.isCancelled, playback == nil else { return }
    let utterance = AVSpeechUtterance(string: cue.text)
    utterance.voice = platformVoice()
    let id = ObjectIdentifier(utterance)
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        guard !Task.isCancelled else {
          continuation.resume()
          return
        }
        playback = continuation
        utteranceID = id
        synthesizer.speak(utterance)
      }
    } onCancel: {
      Task { @MainActor in
        guard self.utteranceID == id else { return }
        self.stop()
      }
    }
  }

  public func stop() {
    synthesizer.stopSpeaking(at: .immediate)
    completePlayback()
  }

  public nonisolated func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
  ) {
    finish(utterance)
  }

  public nonisolated func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
  ) {
    finish(utterance)
  }

  private nonisolated func finish(_ utterance: AVSpeechUtterance) {
    let id = ObjectIdentifier(utterance)
    Task { @MainActor in
      guard self.utteranceID == id else { return }
      self.completePlayback()
    }
  }

  private func completePlayback() {
    utteranceID = nil
    let continuation = playback
    playback = nil
    continuation?.resume()
  }

  public func setBeatInterval(_ interval: TimeInterval?) async {
    // Beats ride a lightweight tick path owned by the app layer;
    // this backend only voices cues. A nil interval is a no-op here.
    _ = interval
  }

  private func platformVoice() -> AVSpeechSynthesisVoice? {
    // Coaching cues are written in English.
    let voices = AVSpeechSynthesisVoice.speechVoices().filter {
      ($0.language == "en" || $0.language.hasPrefix("en-"))
        && $0.voiceTraits.intersection([.isNoveltyVoice, .isPersonalVoice]).isEmpty
    }
    let infos = voices.map {
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
      return AVSpeechSynthesisVoice(language: "en-US")
    }
    return voices.first { $0.identifier == pick.id }
  }
}
