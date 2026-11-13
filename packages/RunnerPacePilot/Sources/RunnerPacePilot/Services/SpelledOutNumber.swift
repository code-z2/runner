//
//  SpelledOutNumber.swift
//  RunnerPacePilot
//
//  Created by Peter on 13/11/2026.
//

import Foundation

/// Numbers as spoken English for TTS cues. Digits and `mm:ss` read badly
/// through a voice model, so the brain spells everything out — the UI can
/// keep showing digits. Always `en_US`: coaching cues are written in
/// English regardless of device locale.
public enum SpelledOutNumber: Sendable {

  /// `42` → `"forty two"`. Hyphens become spaces so the G2P tokenizer
  /// sees plain words.
  public static func words(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.numberStyle = .spellOut
    let spelled = formatter.string(from: value as NSNumber) ?? "\(value)"
    return spelled.replacingOccurrences(of: "-", with: " ")
  }

  /// `42` → `"Forty two"`, for sentence-initial numbers.
  public static func capitalizedWords(_ value: Int) -> String {
    let spelled = words(value)
    guard let first = spelled.first else { return spelled }
    return String(first).uppercased() + spelled.dropFirst()
  }

  /// `(6, 20)` → `"six minutes and twenty seconds"`, with singular forms.
  public static func pace(minutes: Int, seconds: Int) -> String {
    "\(words(minutes)) \(unit(minutes, singular: "minute", plural: "minutes"))"
      + " and \(words(seconds)) \(unit(seconds, singular: "second", plural: "seconds"))"
  }

  private static func unit(_ value: Int, singular: String, plural: String) -> String {
    value == 1 ? singular : plural
  }
}
