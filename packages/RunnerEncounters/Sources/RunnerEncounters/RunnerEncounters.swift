//
//  RunnerEncounters.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

/// Passive runner encounters over BLE: discovery, dedup, display-only counters.
///
/// Agreed spec: `design/ORDER.md` §5 (S01/S02/S03/S05/S06/S07).
/// Rotating anonymous IDs, rotation-proof dedup, graded haptics.
/// Raw events stay on device. Counts carry no in-app powers.
public enum RunnerEncounters {}
