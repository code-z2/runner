//
//  RunnerHealthKit.swift
//  RunnerHealthKit
//
//  Created by Peter on 07/11/2026.
//

/// Native HealthKit boundary: save workouts, read only authorized data.
///
/// Agreed spec: `design/ORDER.md` §11 (native HealthKit integration).
/// The phone has no heart-rate sensor. Absent data reads as unknown, never estimated.
public enum RunnerHealthKit {}
