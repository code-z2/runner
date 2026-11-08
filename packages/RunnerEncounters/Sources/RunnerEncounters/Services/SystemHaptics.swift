//
//  SystemHaptics.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

#if canImport(UIKit)
  import UIKit

  /// System haptics on the main thread. No state, so nothing to synchronize.
  public struct SystemHaptics: EncounterHaptics, Sendable {

    public init() {}

    public func buzz(_ intensity: BuzzIntensity) {
      DispatchQueue.main.async {
        let style: UIImpactFeedbackGenerator.FeedbackStyle =
          switch intensity {
          case .heavy: .heavy
          case .medium: .medium
          case .light: .light
          }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
      }
    }
  }
#endif
