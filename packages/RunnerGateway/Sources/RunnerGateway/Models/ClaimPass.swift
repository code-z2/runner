//
//  ClaimPass.swift
//  RunnerGateway
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// The attestor's signed pass: the second signature of the 2-of-N.
/// Decoded from the `attestation` JSON string inside the response —
/// the outer signature covers exactly these bytes onchain.
public struct ClaimPass: Sendable, Equatable, Decodable {

  public let version: Int
  public let accountID: String
  public let activityHash: String
  public let maxAmountCents: Int
  public let expiresAt: Int
  public let nonce: String
  public let signature: String
  public let runProof: String?
  public let runProofSignature: String?

  public init(
    version: Int,
    accountID: String,
    activityHash: String,
    maxAmountCents: Int,
    expiresAt: Int,
    nonce: String,
    signature: String,
    runProof: String? = nil,
    runProofSignature: String? = nil
  ) {
    self.version = version
    self.accountID = accountID
    self.activityHash = activityHash
    self.maxAmountCents = maxAmountCents
    self.expiresAt = expiresAt
    self.nonce = nonce
    self.signature = signature
    self.runProof = runProof
    self.runProofSignature = runProofSignature
  }

  private enum CodingKeys: String, CodingKey {
    case version = "v"
    case accountID = "account_id"
    case activityHash = "activity_hash"
    case maxAmountCents = "max_amount_cents"
    case expiresAt = "expires_at"
    case nonce
  }

  public init(from decoder: Decoder) throws {
    let envelope = try decoder.container(keyedBy: EnvelopeKeys.self)
    let attestation = try envelope.decode(String.self, forKey: .attestation)
    let signature = try envelope.decode(String.self, forKey: .signature)
    let inner = try JSONDecoder().decode(Inner.self, from: Data(attestation.utf8))
    self.init(
      version: inner.version,
      accountID: inner.accountID,
      activityHash: inner.activityHash,
      maxAmountCents: inner.maxAmountCents,
      expiresAt: inner.expiresAt,
      nonce: inner.nonce,
      signature: signature,
      runProof: try envelope.decodeIfPresent(String.self, forKey: .runProof),
      runProofSignature: try envelope.decodeIfPresent(String.self, forKey: .runProofSignature)
    )
  }

  private enum EnvelopeKeys: String, CodingKey {
    case attestation
    case signature
    case runProof = "run_proof"
    case runProofSignature = "run_proof_signature"
  }

  private struct Inner: Decodable {
    let version: Int
    let accountID: String
    let activityHash: String
    let maxAmountCents: Int
    let expiresAt: Int
    let nonce: String

    private enum CodingKeys: String, CodingKey {
      case version = "v"
      case accountID = "account_id"
      case activityHash = "activity_hash"
      case maxAmountCents = "max_amount_cents"
      case expiresAt = "expires_at"
      case nonce
    }
  }
}
