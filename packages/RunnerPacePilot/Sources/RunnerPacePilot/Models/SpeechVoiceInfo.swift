//
//  SpeechVoiceInfo.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

/// A renderer-agnostic voice descriptor. The selector ranks these with
/// pure logic; adapters map platform voices (Apple speech, Kokoro pack)
/// into this shape. Nothing here touches AVFoundation, so selection is
/// unit-testable and backend-swappable.
public struct SpeechVoiceInfo: Sendable, Equatable {

  public let id: String

  public let name: String

  /// BCP-47, e.g. "en-US".
  public let language: String

  public let quality: VoiceQuality

  public init(id: String, name: String, language: String, quality: VoiceQuality) {
    self.id = id
    self.name = name
    self.language = language
    self.quality = quality
  }
}

public enum VoiceQuality: Int, Sendable, Equatable, Comparable {

  case compact
  case enhanced
  case premium

  public static func < (lhs: VoiceQuality, rhs: VoiceQuality) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}
