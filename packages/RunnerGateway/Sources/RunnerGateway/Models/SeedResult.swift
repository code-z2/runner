//
//  SeedResult.swift
//  RunnerGateway
//
//  Created by Peter on 10/11/2026.
//

/// Seed outcome. `seeded` tells whether this call created the account;
/// `txHash` carries the funder transfer when it did. A dry funder or
/// failed RPC surfaces as `GatewayError.server`, never here.
public struct SeedResult: Sendable, Equatable, Decodable {

  public let seeded: Bool

  public let txHash: String?

  public init(seeded: Bool, txHash: String? = nil) {
    self.seeded = seeded
    self.txHash = txHash
  }

  private enum CodingKeys: String, CodingKey {

    case seeded

    case txHash = "tx"
  }
}
