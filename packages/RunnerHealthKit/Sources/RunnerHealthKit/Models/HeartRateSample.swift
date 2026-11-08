//
//  HeartRateSample.swift
//  RunnerHealthKit
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// One heart-rate reading. Absence of data is `nil` upstream, never zero.
public struct HeartRateSample: Sendable, Equatable {

  public let beatsPerMinute: Double

  public let timestamp: Date

  public init(beatsPerMinute: Double, timestamp: Date) {
    self.beatsPerMinute = beatsPerMinute
    self.timestamp = timestamp
  }
}
