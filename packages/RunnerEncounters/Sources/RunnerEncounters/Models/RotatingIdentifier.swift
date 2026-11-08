//
//  RotatingIdentifier.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// Our own rotating broadcast ID. One root per install; the window index
/// advances on a fixed cadence wider than background scan coalescing, so
/// rotation windows survive throttled delivery.
public struct RotatingIdentifier: Sendable {

  private let root: UUID

  private let windowLength: TimeInterval

  public init(root: UUID, windowLength: TimeInterval = 900) {
    self.root = root
    self.windowLength = windowLength
  }

  public func id(for date: Date) -> String {
    let rootPart = root.uuidString.prefix(8).lowercased()
    return "\(rootPart)-\(windowIndex(for: date))"
  }

  func windowIndex(for date: Date) -> Int {
    Int(date.timeIntervalSince1970 / windowLength)
  }
}
