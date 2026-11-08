//
//  AudioSessionPolicy.swift
//  RunnerPacePilot
//
//  Created by Peter on 08/11/2026.
//

import AVFoundation

/// The auditable audio contract: `.playback` + `.voicePrompt` with duck
/// semantics, activated per cue and released between cues so music dips
/// instead of stopping, then restores. The OS owns duck depth and ramp;
/// this policy only declares intent — never a custom fade curve.
///
/// `releaseBetweenCues` requires the `audio` background mode in the app
/// target: iOS will not reactivate a backgrounded app's session otherwise.
public struct AudioSessionPolicy: Sendable, Equatable {

  public let category: String
  public let mode: String
  public let options: Set<String>
  public let releaseBetweenCues: Bool

  public init(category: String, mode: String, options: Set<String>, releaseBetweenCues: Bool) {
    self.category = category
    self.mode = mode
    self.options = options
    self.releaseBetweenCues = releaseBetweenCues
  }

  public static let voicePrompt = AudioSessionPolicy(
    category: "playback",
    mode: "voicePrompt",
    options: ["duckOthers", "notifyOthersOnDeactivation"],
    releaseBetweenCues: true
  )

  /// Applies the policy to the shared session. Thin on purpose — the
  /// app layer calls this around each rendered cue. iOS only: macOS has
  /// no audio session, so the policy stays declarative there.
  #if os(iOS)
    public func apply() throws {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playback,
        mode: .voicePrompt,
        options: [.duckOthers, .notifyOthersOnDeactivation]
      )
      try session.setActive(true)
    }

    public func release() throws {
      try AVAudioSession.sharedInstance()
        .setActive(false, options: .notifyOthersOnDeactivation)
    }
  #endif
}
