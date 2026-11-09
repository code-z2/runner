//
//  EscrowServiceTests.swift
//  RunnerEscrowTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerEscrowTesting
import RunnerNearTesting
import Testing

@testable import RunnerEscrow

struct EscrowServiceTests {

  private func service(
    rpc: MockNearRpc = MockNearRpc(),
    submitter: MockEscrowSubmitter = MockEscrowSubmitter()
  ) -> (LiveEscrowService, MockNearRpc, MockEscrowSubmitter) {
    (
      LiveEscrowService(rpc: rpc, submitter: submitter, deployment: .placeholder),
      rpc, submitter
    )
  }

  @Test
  func lockForwardsAmountAndGoal() async throws {
    let (service, _, submitter) = service()
    await submitter.scriptReceipt(EscrowReceipt(reference: "r1"))
    let goal = EscrowGoal(distanceM: 10_000, maxSeconds: 3_300)
    let receipt = try await service.lock(amount: "10500000", goal: goal)
    #expect(receipt.reference == "r1")
    #expect(await submitter.calls == [.lock(amount: "10500000", goal: goal)])
  }

  @Test
  func invalidGoalAndAmountNeverReachTheSubmitter() async {
    let (service, _, submitter) = service()
    await #expect(throws: EscrowError.self) {
      try await service.lock(amount: "10500000", goal: EscrowGoal(distanceM: 500))
    }
    await #expect(throws: EscrowError.self) {
      try await service.lock(amount: "10.5", goal: EscrowGoal(distanceM: 10_000))
    }
    await #expect(throws: EscrowError.self) {
      try await service.withdraw(amount: "", receiverID: nil)
    }
    #expect(await submitter.calls.isEmpty)
  }

  @Test
  func unlockForwardsProofBytesUntouched() async throws {
    let (service, _, submitter) = service()
    await submitter.scriptReceipt(EscrowReceipt(reference: "r2"))
    let proof = #"{"v":1,"kind":"run","account_id":"a.near"}"#
    _ = try await service.unlock(lockID: 7, proofJSON: proof, signatureBase64: "c2ln")
    #expect(
      await submitter.calls == [.unlock(lockID: 7, proofJSON: proof, signatureBase64: "c2ln")])
  }

  @Test
  func unlockRefusesEmptyProof() async {
    let (service, _, submitter) = service()
    await #expect(throws: EscrowError.self) {
      try await service.unlock(lockID: 7, proofJSON: "", signatureBase64: "c2ln")
    }
    #expect(await submitter.calls.isEmpty)
  }

  @Test
  func giveUpAndRelockForward() async throws {
    let (service, _, submitter) = service()
    await submitter.scriptReceipt(EscrowReceipt(reference: "r3"))
    await submitter.scriptReceipt(EscrowReceipt(reference: "r4"))
    _ = try await service.giveUp(lockID: 3)
    _ = try await service.relock(amount: "5000000", goal: EscrowGoal(distanceM: 5_000))
    #expect(
      await submitter.calls == [
        .giveUp(lockID: 3),
        .relock(amount: "5000000", goal: EscrowGoal(distanceM: 5_000)),
      ])
  }

  @Test
  func locksViewDecodes() async throws {
    let (service, rpc, _) = service()
    let json = """
      [{"id":7,"owner_id":"a.near","amount":"10500000","goal":{"distance_m":10000,"max_seconds":3300},"created_at":99}]
      """
    await rpc.scriptView(
      contractID: EscrowDeployment.placeholder.escrow, method: "get_locks",
      argsJSON: #"{"account_id":"a.near"}"#, value: Data(json.utf8))
    let locks = try await service.locks(of: "a.near")
    #expect(locks.count == 1)
    #expect(locks[0].id == 7)
    #expect(locks[0].amount == "10500000")
    #expect(locks[0].goal == EscrowGoal(distanceM: 10_000, maxSeconds: 3_300))
  }

  @Test
  func emptyLocksDecodeToEmpty() async throws {
    let (service, rpc, _) = service()
    await rpc.scriptView(
      contractID: EscrowDeployment.placeholder.escrow, method: "get_locks",
      argsJSON: #"{"account_id":"nobody.near"}"#, value: Data("[]".utf8))
    #expect(try await service.locks(of: "nobody.near").isEmpty)
  }

  @Test
  func undecodableViewFailsClosed() async throws {
    let (service, rpc, _) = service()
    await rpc.scriptView(
      contractID: EscrowDeployment.placeholder.escrow, method: "get_locks",
      argsJSON: #"{"account_id":"a.near"}"#, value: Data("nope".utf8))
    await #expect(throws: EscrowError.self) { try await service.locks(of: "a.near") }
  }

  @Test
  func configViewDecodes() async throws {
    let (service, rpc, _) = service()
    let json = """
      {"owner_id":"dao.near","token_id":"usdc.near","treasury_id":"pool.near","attestor_public_key":"ed25519:X","min_lock":"1000000","pool_owed":"0"}
      """
    await rpc.scriptView(
      contractID: EscrowDeployment.placeholder.escrow, method: "get_config",
      argsJSON: "{}", value: Data(json.utf8))
    let config = try await service.config()
    #expect(config.tokenID == "usdc.near")
    #expect(config.minLock == "1000000")
  }
}
