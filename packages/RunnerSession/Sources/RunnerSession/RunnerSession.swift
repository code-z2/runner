//
//  RunnerSession.swift
//  RunnerSession
//
//  Created by Peter on 07/11/2026.
//

/// Workout session state machine: idle → active → paused → finished.
///
/// Agreed spec: `design/ORDER.md` §1 (F01).
/// Transitions are manual-only. Pause freezes the clock. Crash recovery cuts at
/// the last persisted state.
public enum RunnerSession {}
