//
//  NearError.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

/// Every failure mode of this box, typed once. Server and relayer codes
/// travel as values, never prose.
public enum NearError: Sendable, Equatable, Error {

  case invalidInput(String)
  case crypto(String)
  case notLoggedIn
  case loginFailed(String)
  case tokenExpired
  case transport(String)
  case chain(code: String, detail: String)
  case fatxnMismatch
  case relayer(status: Int, code: String)
}
