//
//  RunRecovery.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerSession
import RunnerStore

/// Launch-time crash recovery. Cuts an interrupted run at its last
/// snapshot so the next open shows it as a completed run — the pause
/// rule ("pause freezes the clock") applied to death.
struct RunRecovery: Sendable {

  /// Returns the cut run, or nil when there is nothing to cut. Clears
  /// the snapshot store either way, so recovery runs once.
  func recover(in store: some SessionSnapshotStore) throws -> FinishedRunModel? {
    try WorkoutSession.recoverInterruptedRun(in: store)
  }
}
