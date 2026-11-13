//
//  SpeechVoiceSelector.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// Explicit voice choice wins, followed by quality and then locale.
public enum SpeechVoiceSelector {

  public static func pick(
    from voices: [SpeechVoiceInfo],
    locale: Locale,
    preferredVoiceID: String?
  ) -> SpeechVoiceInfo? {
    if let id = preferredVoiceID,
      let match = voices.first(where: { $0.id == id })
    {
      return match
    }
    let preferredLanguage = locale.identifier.replacingOccurrences(of: "_", with: "-")
    return voices.max {
      if $0.quality != $1.quality { return $0.quality < $1.quality }
      return $0.language.caseInsensitiveCompare(preferredLanguage) != .orderedSame
        && $1.language.caseInsensitiveCompare(preferredLanguage) == .orderedSame
    }
  }
}
