//
//  RunnerAccount.swift
//  RunnerAuth
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// The assembled runner identity. Apple is required; the server session
/// and NEAR session attach as they arrive.
public struct RunnerAccount: Sendable, Equatable {
  public let apple: AppleIdentity
  public let serverSession: String?
  public let near: NearLink?
  public init(apple: AppleIdentity, serverSession: String?, near: NearLink?) {
    self.apple = apple
    self.serverSession = serverSession
    self.near = near
  }
}

/// The chain half of the account. Optional: the app works without
/// payments, so a runner may never link this. Identity linkage only —
/// the id token is the stored credential, expiry and refresh stay with
/// RunnerNear’s provider, so nothing here can pose as a fresh session.
public struct NearLink: Sendable, Equatable {
  public let idToken: String
  public let subject: String
  public let account: NearAccount
  public init(idToken: String, subject: String, account: NearAccount) {
    self.idToken = idToken
    self.subject = subject
    self.account = account
  }
}
