//
//  CadenceSampleModel.swift
//  RunnerCadence
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// One step-rate reading. `nil` means the system reported nothing usable —
/// never estimated, never filled in.
public struct CadenceSampleModel: Sendable, Equatable {

  /// Steps per second, or `nil` when unknown.
  public let stepsPerSecond: Double?

  public let timestamp: Date

  public init(currentCadence: NSNumber?, timestamp: Date) {
    if let currentCadence {
      stepsPerSecond = currentCadence.doubleValue
    } else {
      stepsPerSecond = nil
    }
    self.timestamp = timestamp
  }
}
