//
//  RunnerNear.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

/// NEAR for the app: passkey login, MPC-backed signing, chain reads and
/// writes. Swift owns login + orchestration; `runner-near-core` (Rust)
/// owns every chain byte. No JS toolchain ships in this box.
///
/// Agreed shape: single package, passkeys only, no social login.
/// Social or Privy alternatives stay behind the `NearSigner` seam.
public enum RunnerNear {}
