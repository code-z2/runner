//
//  DeviceRegistration.swift
//  RunnerGateway
//
//  Created by Peter on 08/11/2026.
//

/// App Attest key registration. The attestation bytes are produced by
/// the platform layer (DeviceCheck on device); the gateway only carries
/// them. One registration per install; repeats return `device_exists`.
public struct DeviceRegistration: Sendable, Equatable, Encodable {

  public let keyID: String
  public let attestation: String
  public let challenge: String

  public init(keyID: String, attestation: String, challenge: String) {
    self.keyID = keyID
    self.attestation = attestation
    self.challenge = challenge
  }

  private enum CodingKeys: String, CodingKey {
    case keyID = "key_id"
    case attestation
    case challenge
  }
}
