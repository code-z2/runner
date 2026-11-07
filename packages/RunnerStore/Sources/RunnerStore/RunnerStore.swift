//
//  RunnerStore.swift
//  RunnerStore
//
//  Created by Peter on 07/11/2026.
//

/// On-device persistence: workout history, personal bests, retention policy.
///
/// Agreed spec: `design/ORDER.md` §11 (device-only history and bests).
/// Nothing here leaves the device. Secrets live in the Keychain, never in the store.
public enum RunnerStore {}
