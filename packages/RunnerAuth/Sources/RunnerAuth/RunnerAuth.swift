//
//  RunnerAuth.swift
//  RunnerAuth
//
//  Created by Peter on 07/11/2026.
//

/// Wallet entry: Apple social login mapped to the runner's NEAR account.
///
/// Agreed spec: `design/ORDER.md` §4 + §9 (F11, wallet stack).
/// No seed phrase. Same address across sessions. Required only at wallet entry,
/// never for running.
public enum RunnerAuth {}
