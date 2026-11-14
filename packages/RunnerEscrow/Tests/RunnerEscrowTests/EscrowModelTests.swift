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

struct EscrowFunctionCallTests {

  @Test
  func depositMessageMatchesTheDeployedDepositMsg() throws {
    let id = try #require(UUID(uuidString: "0F6C4A0E-1B7A-4C1E-9C1B-2D3E4F5A6B7C"))
    let message = try EscrowGoal(distanceM: 10_000, maxSeconds: 3_300)
      .depositMessage(owner: "abc", fundingID: id)
    #expect(
      message
        == #"{"funding_id":"0f6c4a0e-1b7a-4c1e-9c1b-2d3e4f5a6b7c","goal":{"distance_m":10000,"max_seconds":3300},"owner":"abc"}"#
    )
  }

  @Test
  func withdrawAndUnlockMapToEscrowCalls() throws {
    let withdraw = try EscrowCall.withdraw(amount: "5000000", receiverID: "dep.near")
      .functionCall(on: .mainnet)
    #expect(withdraw.receiverID == "ije-v1-escrow.codez2.near")
    #expect(withdraw.method == "withdraw")
    #expect(withdraw.depositYocto == "1")
    #expect(withdraw.argsJSON == #"{"amount":"5000000","receiver_id":"dep.near"}"#)

    let unlock = try EscrowCall.unlock(lockID: 7, proofJSON: #"{"v":1}"#, signatureBase64: "c2ln")
      .functionCall(on: .mainnet)
    #expect(unlock.method == "unlock")
    #expect(unlock.depositYocto == "0")
    #expect(unlock.argsJSON == #"{"lock_id":"7","proof":"{\"v\":1}","signature":"c2ln"}"#)
  }
}

struct EscrowLockDecodingTests {

  @Test
  func decodesTheDeployedGetLocksShape() throws {
    let json =
      #"[{"id":"0","owner_id":"8cb5a453","amount":"5000000","goal":{"distance_m":1000,"max_seconds":2100},"created_at":"1794668315364971571"}]"#
    let locks = try JSONDecoder().decode([EscrowLock].self, from: Data(json.utf8))
    #expect(locks.first?.id == 0)
    #expect(locks.first?.amount == "5000000")
    #expect(locks.first?.createdAt == 1_794_668_315_364_971_571)
    #expect(locks.first?.goal == EscrowGoal(distanceM: 1_000, maxSeconds: 2_100))
  }
}
