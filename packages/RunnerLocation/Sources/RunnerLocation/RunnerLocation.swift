//
//  RunnerLocation.swift
//  RunnerLocation
//
//  Created by Peter on 07/11/2026.
//

/// Live location telemetry: Core Location deltas exactly as iOS delivers them.
///
/// Agreed spec: `design/ORDER.md` §2 (F02).
/// No custom filtering, no smoothing, no estimation. Invalid speed reads as unknown.
public enum RunnerLocation {}
