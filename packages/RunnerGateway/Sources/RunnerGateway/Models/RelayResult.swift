//
//  RelayResult.swift
//  RunnerGateway
//
//  Created by Peter on 10/11/2026.
//

import Foundation

/// Relay outcome. A `failed` status means the transaction ran and the
/// contract refused it — the transaction hash is the receipt, and the
/// failure detail stays onchain under it.
public struct RelayResult: Sendable, Equatable, Decodable {

  public enum Status: String, Sendable, Equatable, Decodable {

    case succeeded

    case failed
  }

  public let transactionHash: String

  public let status: Status

  public init(transactionHash: String, status: Status) {
    self.transactionHash = transactionHash
    self.status = status
  }

  private enum CodingKeys: String, CodingKey {

    case transactionHash = "transaction_hash"

    case status
  }
}
