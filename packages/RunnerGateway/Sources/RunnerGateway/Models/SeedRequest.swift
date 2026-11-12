//
//  SeedRequest.swift
//  RunnerGateway
//
//  Created by Peter on 10/11/2026.
//

/// Seed request. The account ID is the runner's implicit address; the
/// server checks existence and funds it once. Same device +
/// key-ownership guards as claims, minus the run proof: `assertion`
/// binds the request to the registered device key and `nearSignature`
/// (over `seed:<account_id>`) binds it to the runner's full-access
/// account key.
public struct SeedRequest: Sendable, Equatable, Encodable {

  public let accountID: String
  public let keyID: String
  public let assertion: String
  public let nearPublicKey: String
  public let nearSignature: String

  public init(
    accountID: String,
    keyID: String,
    assertion: String,
    nearPublicKey: String,
    nearSignature: String
  ) {
    self.accountID = accountID
    self.keyID = keyID
    self.assertion = assertion
    self.nearPublicKey = nearPublicKey
    self.nearSignature = nearSignature
  }

  private enum CodingKeys: String, CodingKey {

    case accountID = "account_id"
    case keyID = "key_id"
    case assertion
    case nearPublicKey = "near_public_key"
    case nearSignature = "near_signature"
  }
}
