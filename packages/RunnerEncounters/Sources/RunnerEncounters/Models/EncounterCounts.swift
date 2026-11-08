//
//  EncounterCounts.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

/// Display-only numbers. They carry no in-app powers or rewards.
public struct EncounterCounts: Sendable, Equatable {

  public let first: Int

  public let `repeat`: Int

  public let dwell: Int

  public init(first: Int, repeat repeatCount: Int, dwell: Int) {
    self.first = first
    self.repeat = repeatCount
    self.dwell = dwell
  }
}
