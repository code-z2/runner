//
//  RunnerAuth.swift
//  RunnerAuth
//
//  Created by Peter on 09/11/2026.
//

/// Runner identity: Apple sign-in for API auth, NEAR passkey session for
/// chain ops. Presentation stays app-layer; this box owns request values,
/// token parsing/validation, the Keychain session, and the coordinator.
/// Chain signing programs against RunnerNear's `NearSigner`.
public struct RunnerAuth {

  /// Keychain service namespace. One blob, atomic.
  public static let service = "io.wades.ije.auth"

  /// Persisted account key. Versioned so rotation never collides.
  public static let accountKey = "runner.account.v1"

  /// Device-key secret. Separate item so only key material carries the
  /// biometric gate; identity fields stay silent in the account blob.
  /// Versioned alongside the blob it belongs to.
  public static let localKey = "runner.localkey.v1"

  /// Keychain access group for future Watch sharing. Reserved, unused
  /// until the Watch app target exists.
  public static let accessGroup = "group.io.wades.ije.auth"
}
