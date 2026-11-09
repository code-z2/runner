//
//  AuthTransport.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// The seam to Auth0 + relayer HTTP. Deliberately separate from the
/// gateway's transport: OAuth error envelopes and token semantics are
/// auth business, not API business.
public protocol AuthTransport: Sendable {

  func send(_ request: URLRequest) async throws -> (Data, Int)
}
