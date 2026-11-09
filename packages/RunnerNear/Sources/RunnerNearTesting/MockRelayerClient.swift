//
//  MockRelayerClient.swift
//  RunnerNearTesting
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// Scripted MPC answers. Records every request so tests assert the exact
/// bytes the network would sign — the relayer URL and response parsing
/// are verified live on testnet before the live client ships.
public actor MockRelayerClient: RelayerClient {

  public private(set) var requests: [SignatureRequest] = []
  private var signature = Data(repeating: 0, count: 64)

  public init() {}

  public func scriptSignature(_ bytes: Data) {
    signature = bytes
  }

  public func requestSignature(_ request: SignatureRequest) async throws -> Data {
    requests.append(request)
    return signature
  }
}
