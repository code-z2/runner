//
//  ClaimPassRequest.swift
//  RunnerGateway
//
//  Created by Peter on 08/11/2026.
//

/// Claim-pass request. `payload` is the app-built JSON string
/// (`account_id`, `challenge`, `activity`); `assertion` binds it to the
/// registered device key and `nearSignature` (NEP-413) binds it to the
/// runner's full-access account key. The gateway never sees run history —
/// only the strings the platform and wallet layers produced.
public struct ClaimPassRequest: Sendable, Equatable, Encodable {

  public let payload: String
  public let keyID: String
  public let assertion: String
  public let nearPublicKey: String
  public let nearSignature: String

  public init(
    payload: String,
    keyID: String,
    assertion: String,
    nearPublicKey: String,
    nearSignature: String
  ) {
    self.payload = payload
    self.keyID = keyID
    self.assertion = assertion
    self.nearPublicKey = nearPublicKey
    self.nearSignature = nearSignature
  }

  private enum CodingKeys: String, CodingKey {
    case payload
    case keyID = "key_id"
    case assertion
    case nearPublicKey = "near_public_key"
    case nearSignature = "near_signature"
  }
}
