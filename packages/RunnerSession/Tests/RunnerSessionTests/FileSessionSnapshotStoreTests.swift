//
//  FileSessionSnapshotStoreTests.swift
//  RunnerSessionTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import Testing

@testable import RunnerSession

struct FileSessionSnapshotStoreTests {

  private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  @Test
  func saveLoadRoundTrip() throws {
    let store = FileSessionSnapshotStore(directory: try temporaryDirectory())
    let snapshot = SessionSnapshotModel(
      id: UUID(),
      startedAtWall: Date(timeIntervalSince1970: 1_000),
      accumulatedActive: 42.0,
      state: .paused,
      batteryLevelAtStart: 0.8,
      batteryLevel: 0.75,
      checkpointAtWall: Date(timeIntervalSince1970: 1_042)
    )

    try store.save(snapshot)

    #expect(try store.load() == snapshot)
  }

  @Test
  func missingSnapshotLoadsNil() throws {
    let store = FileSessionSnapshotStore(directory: try temporaryDirectory())

    #expect(try store.load() == nil)
  }

  @Test
  func clearRemovesSnapshot() throws {
    let store = FileSessionSnapshotStore(directory: try temporaryDirectory())
    let snapshot = SessionSnapshotModel(
      id: UUID(),
      startedAtWall: Date(timeIntervalSince1970: 1_000),
      accumulatedActive: 42.0,
      state: .active,
      batteryLevelAtStart: 0.8,
      batteryLevel: 0.75,
      checkpointAtWall: Date(timeIntervalSince1970: 1_042)
    )
    try store.save(snapshot)

    try store.clear()

    #expect(try store.load() == nil)
  }
}
