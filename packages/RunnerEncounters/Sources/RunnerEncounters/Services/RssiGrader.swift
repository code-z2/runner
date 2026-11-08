//
//  RssiGrader.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// Pure proximity grading: lighter at a distance, heavier up close,
/// with a per-peer cooldown so one encounter buzzes once, not constantly.
public struct RssiGrader {

  public static let cooldown: TimeInterval = 30

  private var lastBuzz: [UUID: Date] = [:]

  public init() {}

  public mutating func grade(peer: UUID, rssi: Int, at: Date) -> BuzzIntensity? {
    if let last = lastBuzz[peer], at.timeIntervalSince(last) < Self.cooldown {
      return nil
    }
    lastBuzz[peer] = at
    switch rssi {
    case -60...Int.max:
      return .heavy
    case -80 ..< -60:
      return .medium
    default:
      return .light
    }
  }
}
