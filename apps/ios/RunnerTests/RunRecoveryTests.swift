//
//  RunRecoveryTests.swift
//  RunnerTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerSession
import RunnerSessionTesting
import Testing

@testable import Runner

struct RunRecoveryTests {

  private func snapshot(state: SessionState) -> SessionSnapshotModel {
    SessionSnapshotModel(
      id: UUID(), startedAtWall: Date(), accumulatedActive: 60, state: state,
      batteryLevelAtStart: nil, batteryLevel: nil, checkpointAtWall: Date())
  }

  @Test
  func emptyStoreReturnsNil() throws {
    #expect(try RunRecovery().recover(in: InMemorySessionSnapshotStore()) == nil)
  }

  @Test
  func activeSnapshotCutsARun() throws {
    let store = InMemorySessionSnapshotStore()
    try store.save(snapshot(state: .active))
    let cut = try RunRecovery().recover(in: store)
    #expect(cut != nil)
    #expect(try store.load() == nil)
  }

  @Test
  func finishedSnapshotYieldsNothing() throws {
    let store = InMemorySessionSnapshotStore()
    try store.save(snapshot(state: .finished))
    #expect(try RunRecovery().recover(in: store) == nil)
  }
}
