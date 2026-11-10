//
//  RelayRequest.swift
//  RunnerGateway
//
//  Created by Peter on 10/11/2026.
//

import Foundation

/// One NEP-366 delegate submission. The bytes are built and signed in
/// `RunnerNear`; the App Attest `assertion` for `key_id` comes from the
/// device layer. The gateway only moves them to `POST /v1/relay`.
public struct RelayRequest: Sendable, Equatable, Encodable {

  public let signedDelegateB64: String
  public let keyID: String
  public let assertionB64: String

  public init(signedDelegateB64: String, keyID: String, assertionB64: String) {
    self.signedDelegateB64 = signedDelegateB64
    self.keyID = keyID
    self.assertionB64 = assertionB64
  }

  private enum CodingKeys: String, CodingKey {

    case signedDelegateB64 = "signed_delegate"

    case keyID = "key_id"

    case assertionB64 = "assertion"
  }
}
