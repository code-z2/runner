//
//  AuditLog.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import os

/// Redacted audit trail for security events: sign-in/out, session
/// restores, failed ceremony attempts. User IDs are hashed so a log
/// archive never carries identity in the clear. No tokens, ever.
struct AuditLog: Sendable {

  private let log = Logger(subsystem: "io.wades.ije", category: "auth")

  func signedIn(userID: String) {
    log.notice("sign-in ok user=\(userID, privacy: .private(mask: .hash))")
  }

  func signedInRestored(userID: String) {
    log.info("session restored user=\(userID, privacy: .private(mask: .hash))")
  }

  func signedOut() {
    log.notice("sign-out ok")
  }

  func ceremonyFailed(_ reason: String) {
    log.error("ceremony failed reason=\(reason, privacy: .public)")
  }
}
