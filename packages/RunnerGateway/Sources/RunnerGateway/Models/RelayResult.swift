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

  /// Every receipt's logs, in order. A call can succeed without doing what
  /// was asked; the contract's logs say what it did.
  public let logs: [String]

  public init(transactionHash: String, status: Status, logs: [String] = []) {
    self.transactionHash = transactionHash
    self.status = status
    self.logs = logs
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      transactionHash: try container.decode(String.self, forKey: .transactionHash),
      status: try container.decode(Status.self, forKey: .status),
      logs: try container.decodeIfPresent([String].self, forKey: .logs) ?? [])
  }

  private enum CodingKeys: String, CodingKey {

    case transactionHash = "transaction_hash"

    case status

    case logs
  }
}
