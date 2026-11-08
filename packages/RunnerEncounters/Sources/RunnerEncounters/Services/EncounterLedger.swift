//
//  EncounterLedger.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// Pure pass-by counting. One pass is one count: a new peer counts first,
/// a peer back after the repeat gap counts repeat, and unbroken presence
/// past the dwell threshold counts dwell once. Known peers prune after
/// thirty days so storage stays bounded.
public struct EncounterLedger {

  public static let repeatGap: TimeInterval = 300

  public static let dwellThreshold: TimeInterval = 60

  public static let retention: TimeInterval = 30 * 24 * 3_600

  private struct Visit {
    var firstSeen: Date
    var lastSeen: Date
    var dwellFired: Bool
  }

  private var visits: [UUID: Visit] = [:]

  private var firstCount = 0

  private var repeatCount = 0

  private var dwellCount = 0

  private let now: @Sendable () -> Date

  public init(now: @Sendable @escaping () -> Date = Date.init) {
    self.now = now
  }

  public var counts: EncounterCounts {
    EncounterCounts(first: firstCount, repeat: repeatCount, dwell: dwellCount)
  }

  public mutating func record(_ sighting: ProximitySighting) -> [EncounterEffect] {
    prune()
    let id = sighting.peer.peripheralID
    guard var visit = visits[id] else {
      visits[id] = Visit(firstSeen: sighting.at, lastSeen: sighting.at, dwellFired: false)
      firstCount += 1
      return [.countedFirst]
    }
    if sighting.at.timeIntervalSince(visit.lastSeen) >= Self.repeatGap {
      visit = Visit(firstSeen: sighting.at, lastSeen: sighting.at, dwellFired: false)
      visits[id] = visit
      repeatCount += 1
      return [.countedRepeat]
    }
    visit.lastSeen = sighting.at
    visits[id] = visit
    if !visit.dwellFired, sighting.at.timeIntervalSince(visit.firstSeen) >= Self.dwellThreshold {
      visits[id]?.dwellFired = true
      dwellCount += 1
      return [.dwellReached]
    }
    return []
  }

  private mutating func prune() {
    let cutoff = now().addingTimeInterval(-Self.retention)
    visits = visits.filter { $0.value.lastSeen >= cutoff }
  }
}
