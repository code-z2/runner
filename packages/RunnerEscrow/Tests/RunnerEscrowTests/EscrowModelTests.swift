//
//  EscrowModelTests.swift
//  RunnerEscrowTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import Testing

@testable import RunnerEscrow

struct EscrowModelTests {

  @Test
  func goalBoundsMirrorTheContract() throws {
    #expect(throws: EscrowError.self) { try EscrowGoal(distanceM: 999).validated() }
    #expect(throws: EscrowError.self) { try EscrowGoal(distanceM: 100_001).validated() }
    #expect(throws: EscrowError.self) {
      try EscrowGoal(distanceM: 10_000, maxSeconds: 59).validated()
    }
    #expect(throws: EscrowError.self) {
      try EscrowGoal(distanceM: 10_000, maxSeconds: 86_401).validated()
    }
    try EscrowGoal(distanceM: 1_000).validated()
    try EscrowGoal(distanceM: 100_000, maxSeconds: 86_400).validated()
  }

  @Test
  func memoIsTheExactContractBytes() throws {
    #expect(
      try EscrowGoal(distanceM: 10_000, maxSeconds: 3_300).memoJSON()
        == #"{"distance_m":10000,"max_seconds":3300}"#)
    #expect(try EscrowGoal(distanceM: 10_000).memoJSON() == #"{"distance_m":10000}"#)
  }

  @Test
  func invalidGoalNeverReachesAMemo() {
    #expect(throws: EscrowError.self) { try EscrowGoal(distanceM: 500).memoJSON() }
  }

  @Test
  func longerRunCountsByPace() {
    let goal = EscrowGoal(distanceM: 10_000, maxSeconds: 3_300)
    #expect(goal.meets(distanceM: 10_000, activeSeconds: 3_000))
    #expect(goal.meets(distanceM: 12_000, activeSeconds: 3_900))
  }

  @Test
  func slowOrShortRunDoesNotMeet() {
    let goal = EscrowGoal(distanceM: 10_000, maxSeconds: 3_300)
    #expect(!goal.meets(distanceM: 10_000, activeSeconds: 3_600))
    #expect(!goal.meets(distanceM: 5_000, activeSeconds: 1_500))
  }

  @Test
  func untimedGoalNeedsDistanceOnly() {
    let goal = EscrowGoal(distanceM: 10_000)
    #expect(goal.meets(distanceM: 15_000, activeSeconds: 99_999))
    #expect(!goal.meets(distanceM: 9_999, activeSeconds: 1))
  }

  @Test
  func usdcHelperStaysInBaseUnits() {
    #expect(EscrowAmount.usdc("10.50") == "10500000")
    #expect(EscrowAmount.usdc("0.000001") == "1")
    #expect(EscrowAmount.usdc("0.0000001") == nil)
    #expect(EscrowAmount.usdc("abc") == nil)
    #expect(EscrowAmount.usdc("-1") == nil)
  }

  @Test
  func runProofParsesForDisplayOnly() throws {
    let json = """
      {"v":1,"kind":"run","account_id":"a.near","activity_hash":"ab","started_at":100,"ended_at":200,"distance_m":10000,"active_seconds":3000}
      """
    let proof = try JSONDecoder().decode(RunProof.self, from: Data(json.utf8))
    #expect(proof.distanceM == 10_000)
    #expect(proof.accountID == "a.near")
  }
}
