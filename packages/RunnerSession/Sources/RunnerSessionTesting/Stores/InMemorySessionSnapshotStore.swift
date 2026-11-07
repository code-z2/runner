//
//  InMemorySessionSnapshotStore.swift
//  RunnerSessionTesting
//
//  Created by Peter on 07/11/2026.
//

import Foundation

@testable import RunnerSession

/// In-memory snapshot store. Single-threaded test use only.
public final class InMemorySessionSnapshotStore: SessionSnapshotStore, @unchecked Sendable {

  private var stored: SessionSnapshotModel?

  public init() {}

  public func save(_ snapshot: SessionSnapshotModel) throws {
    stored = snapshot
  }

  public func load() throws -> SessionSnapshotModel? {
    stored
  }

  public func clear() throws {
    stored = nil
  }
}
