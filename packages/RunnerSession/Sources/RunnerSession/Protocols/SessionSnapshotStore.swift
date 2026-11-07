//
//  SessionSnapshotStore.swift
//  RunnerSession
//
//  Created by Peter on 07/11/2026.
//

/// Persists the active draft so a terminated app can cut the run honestly.
public protocol SessionSnapshotStore: Sendable {

  func save(_ snapshot: SessionSnapshotModel) throws

  func load() throws -> SessionSnapshotModel?

  func clear() throws
}
