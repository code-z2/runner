//
//  SpeechVoiceSelectorTests.swift
//  RunnerPacePilotTests
//
//  Created by Peter on 08/11/2026.
//

import Foundation
import Testing

@testable import RunnerPacePilot

struct SpeechVoiceSelectorTests {

  private func voice(
    id: String = "a",
    language: String = "en-US",
    quality: VoiceQuality = .compact
  ) -> SpeechVoiceInfo {
    SpeechVoiceInfo(id: id, name: id, language: language, quality: quality)
  }

  @Test
  func prefersPremiumInLocale() {
    let voices = [
      voice(id: "compact", quality: .compact),
      voice(id: "premium", quality: .premium),
      voice(id: "enhanced", quality: .enhanced),
    ]
    let picked = SpeechVoiceSelector.pick(
      from: voices,
      locale: Locale(identifier: "en-US"),
      preferredVoiceID: nil
    )
    #expect(picked?.id == "premium")
  }

  @Test
  func prefersPremiumOverLocalEnhancedVoice() {
    let voices = [
      voice(id: "local", quality: .enhanced),
      voice(id: "premium", language: "en-GB", quality: .premium),
    ]
    #expect(
      SpeechVoiceSelector.pick(
        from: voices, locale: Locale(identifier: "en-US"), preferredVoiceID: nil
      )?.id == "premium")
  }

  @Test
  func prefersLocalVoiceAtTheSameQuality() {
    let voices = [
      voice(id: "other", language: "en-GB", quality: .premium),
      voice(id: "local", quality: .premium),
    ]
    #expect(
      SpeechVoiceSelector.pick(
        from: voices, locale: Locale(identifier: "en-US"), preferredVoiceID: nil
      )?.id == "local")
  }

  @Test
  func preferredVoiceIDWins() {
    let voices = [
      voice(id: "premium", quality: .premium),
      voice(id: "mine", quality: .compact),
    ]
    let picked = SpeechVoiceSelector.pick(
      from: voices,
      locale: Locale(identifier: "en-US"),
      preferredVoiceID: "mine"
    )
    #expect(picked?.id == "mine")
  }

  @Test
  func unknownPreferredIDFallsBackToPremium() {
    let voices = [voice(id: "premium", quality: .premium)]
    let picked = SpeechVoiceSelector.pick(
      from: voices,
      locale: Locale(identifier: "en-US"),
      preferredVoiceID: "gone"
    )
    #expect(picked?.id == "premium")
  }

  @Test
  func emptyCatalogPicksNothing() {
    #expect(
      SpeechVoiceSelector.pick(
        from: [],
        locale: Locale(identifier: "en-US"),
        preferredVoiceID: nil
      ) == nil
    )
  }

  @Test
  func audioPolicyDucksButNeverStopsMusic() {
    let policy = AudioSessionPolicy.voicePrompt
    #expect(policy.category == "playback")
    #expect(policy.mode == "voicePrompt")
    #expect(policy.options.contains("duckOthers"))
    #expect(!policy.options.contains("stopOthers"))
    #expect(policy.releaseBetweenCues)
  }
}
