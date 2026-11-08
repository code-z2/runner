//
//  PersonalBestsSnapshot.swift
//  RunnerStore
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// Best-of-history numbers, computed on demand. Empty history reads as zeros.
public struct PersonalBestsSnapshot: Sendable, Equatable {

  public let longest: RunRecordSnapshot?

  public let fastestPaceSecondsPerMeter: Double?

  public let totalRuns: Int

  public let totalActiveTime: TimeInterval
}
