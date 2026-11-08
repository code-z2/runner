//
//  SpeechVoiceSelector.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// Pure voice ranking. Explicit user choice wins; otherwise the best
/// quality voice in the runner's locale, falling back to the best
/// quality anywhere. v1 feeds this from Apple speech (premium-first);
/// the Kokoro voice pack feeds the same ranking later.
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
    let languagePrefix = String(locale.identifier.prefix(2)).lowercased()
    let local = voices.filter { $0.language.lowercased().hasPrefix(languagePrefix) }
    if let best = local.max(by: { $0.quality < $1.quality }) { return best }
    return voices.max(by: { $0.quality < $1.quality })
  }
}
