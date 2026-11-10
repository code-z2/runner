//
//  SeedRequest.swift
//  RunnerGateway
//
//  Created by Peter on 10/11/2026.
//

/// Seed request. The account ID is the runner's implicit address; the
/// server checks existence and funds it once. Same SIWA + App Attest
/// guards as claims, minus the run proof.
public struct SeedRequest: Sendable, Equatable, Encodable {

  public let accountID: String

  public init(accountID: String) {
    self.accountID = accountID
  }

  private enum CodingKeys: String, CodingKey {

    case accountID = "account_id"
  }
}
