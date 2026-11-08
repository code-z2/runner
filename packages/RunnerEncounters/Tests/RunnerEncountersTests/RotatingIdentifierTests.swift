//
//  RotatingIdentifierTests.swift
//  RunnerEncountersTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import Testing

@testable import RunnerEncounters

struct RotatingIdentifierTests {

  @Test
  func sameWindowYieldsSameID() {
    let rotation = RotatingIdentifier(root: UUID(), windowLength: 900)
    let base = Date(timeIntervalSince1970: 9_900)

    #expect(rotation.id(for: base) == rotation.id(for: base.addingTimeInterval(899)))
  }

  @Test
  func nextWindowYieldsDifferentID() {
    let rotation = RotatingIdentifier(root: UUID(), windowLength: 900)
    let base = Date(timeIntervalSince1970: 9_900)

    #expect(rotation.id(for: base) != rotation.id(for: base.addingTimeInterval(900)))
  }

  @Test
  func differentInstallsNeverShareIDs() {
    let first = RotatingIdentifier(root: UUID(), windowLength: 900)
    let second = RotatingIdentifier(root: UUID(), windowLength: 900)
    let at = Date(timeIntervalSince1970: 10_000)

    #expect(first.id(for: at) != second.id(for: at))
  }
}
