//
//  RelayerClient.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// MPC signature requests. The request shape mirrors Peersyst's
/// `SignatureRequest`; the endpoint URL comes from `NearNetwork` and
/// is verified live on testnet before use.
public protocol RelayerClient: Sendable {

  /// Returns the raw signature bytes.
  func requestSignature(_ request: SignatureRequest) async throws -> Data
}
