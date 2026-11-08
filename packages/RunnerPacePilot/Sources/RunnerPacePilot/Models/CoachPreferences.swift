//
//  CoachPreferences.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

/// The complete opt-in surface. Everything the coach can say or play
/// flows through here, and the master switch ships off: nothing speaks
/// until the runner explicitly arms the coach. The app layer persists
/// these; the scheduler only reads them.
public struct CoachPreferences: Sendable, Equatable {

  public var masterEnabled: Bool

  public var voiceEnabled: Bool

  public var beatsEnabled: Bool

  /// Persisted voice choice: a system voice identifier, or `"personal"`
  /// when the runner opts into their own Personal Voice. `nil` means
  /// premium-first automatic selection.
  public var preferredVoiceID: String?

  public init(
    masterEnabled: Bool = false,
    voiceEnabled: Bool = true,
    beatsEnabled: Bool = true,
    preferredVoiceID: String? = nil
  ) {
    self.masterEnabled = masterEnabled
    self.voiceEnabled = voiceEnabled
    self.beatsEnabled = beatsEnabled
    self.preferredVoiceID = preferredVoiceID
  }
}
