//
//  RssiGraderTests.swift
//  RunnerEncountersTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import Testing

@testable import RunnerEncounters

struct RssiGraderTests {

  @Test(arguments: [
    (-40, BuzzIntensity.heavy),
    (-60, BuzzIntensity.heavy),
    (-61, BuzzIntensity.medium),
    (-80, BuzzIntensity.medium),
    (-81, BuzzIntensity.light),
    (-100, BuzzIntensity.light),
  ])
  func bandsMapRssiToIntensity(rssi: Int, expected: BuzzIntensity) {
    var grader = RssiGrader()
    let peer = UUID()

    #expect(grader.grade(peer: peer, rssi: rssi, at: Date()) == expected)
  }

  @Test
  func cooldownSuppressesRapidRebuzz() {
    var grader = RssiGrader()
    let peer = UUID()
    let at = Date(timeIntervalSince1970: 10_000)

    #expect(grader.grade(peer: peer, rssi: -50, at: at) == .heavy)
    #expect(grader.grade(peer: peer, rssi: -50, at: at.addingTimeInterval(10)) == nil)
    #expect(grader.grade(peer: peer, rssi: -50, at: at.addingTimeInterval(31)) == .heavy)
  }

  @Test
  func cooldownIsPerPeer() {
    var grader = RssiGrader()
    let at = Date(timeIntervalSince1970: 10_000)

    #expect(grader.grade(peer: UUID(), rssi: -50, at: at) == .heavy)
    #expect(grader.grade(peer: UUID(), rssi: -50, at: at) == .heavy)
  }
}
