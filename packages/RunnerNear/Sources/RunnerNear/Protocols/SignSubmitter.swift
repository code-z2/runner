//
//  SignSubmitter.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// Submits the on-chain `sign` call and returns the MPC signature bytes.
/// Production is a controlled relayer (server-held, gas-only, auditable);
/// testnet proof runs through the core directly with a dev-funded key in
/// scratch — never through this box.
public protocol SignSubmitter: Sendable {

  func submit(
    guardID: String,
    jwt: String,
    signPayload: Data,
    algorithm: SignatureRequest.Algorithm
  ) async throws -> Data
}
