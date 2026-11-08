//
//  Challenge.swift
//  RunnerGateway
//
//  Created by Peter on 08/11/2026.
//

/// Single-use server challenge. Consumed by exactly one device
/// registration or claim-pass request, then expires in 5 minutes.
public struct Challenge: Sendable, Equatable, Decodable {

  public let value: String

  public init(value: String) {
    self.value = value
  }

  private enum CodingKeys: String, CodingKey {
    case value = "challenge"
  }
}
