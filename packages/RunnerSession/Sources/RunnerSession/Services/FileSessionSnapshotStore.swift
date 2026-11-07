//
//  FileSessionSnapshotStore.swift
//  RunnerSession
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// Atomic JSON snapshot in an injected directory. The app passes its
/// application-support directory; tests pass a temporary one.
public struct FileSessionSnapshotStore: SessionSnapshotStore, Sendable {

  private let fileURL: URL

  public init(directory: URL, filename: String = "active-session.json") {
    self.fileURL = directory.appendingPathComponent(filename, isDirectory: false)
  }

  public func save(_ snapshot: SessionSnapshotModel) throws {
    let data = try JSONEncoder().encode(snapshot)
    try data.write(to: fileURL, options: .atomic)
  }

  public func load() throws -> SessionSnapshotModel? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return nil
    }
    let data = try Data(contentsOf: fileURL)
    return try JSONDecoder().decode(SessionSnapshotModel.self, from: data)
  }

  public func clear() throws {
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }
  }
}
