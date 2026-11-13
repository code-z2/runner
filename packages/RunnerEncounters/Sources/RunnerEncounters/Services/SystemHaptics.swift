//
//  SystemHaptics.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

#if canImport(UIKit)
  import UIKit

  /// Fixed double-double notification buzz: (vh vh), (vh vh).
  /// The intensity is deliberately ignored — every counted encounter feels
  /// identical. `RssiGrader` still decides *when* to buzz (per-peer
  /// cooldown); this type only decides *how it feels*.
  public struct SystemHaptics: EncounterHaptics, Sendable {

    /// Gap between the two taps inside a pair.
    private static let tapGap: TimeInterval = 0.09

    /// Gap between the two pairs.
    private static let pairGap: TimeInterval = 0.28

    public init() {}

    public func buzz(_ intensity: BuzzIntensity) {
      DispatchQueue.main.async {
        Self.fire()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.tapGap) { Self.fire() }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.tapGap + Self.pairGap) {
          Self.fire()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.tapGap * 2 + Self.pairGap) {
          Self.fire()
        }
      }
    }

    @MainActor
    private static func fire() {
      let generator = UINotificationFeedbackGenerator()
      generator.prepare()
      generator.notificationOccurred(.success)
    }
  }
#endif
