//
//  MockSignSubmitter.swift
//  RunnerNearTesting
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// Scripted sign submission. Records guard/JWT/payload so tests assert
/// the exact bytes the MPC network would sign.
public actor MockSignSubmitter: SignSubmitter {

  public struct Submission: Sendable {
    public let guardID: String
    public let jwt: String
    public let payload: Data
    public let algorithm: SignatureRequest.Algorithm
  }

  public private(set) var submissions: [Submission] = []
  private var signature = Data(repeating: 9, count: 64)

  public init() {}

  public func scriptSignature(_ bytes: Data) { signature = bytes }

  public func submit(
    guardID: String,
    jwt: String,
    signPayload: Data,
    algorithm: SignatureRequest.Algorithm
  ) async throws -> Data {
    submissions.append(
      Submission(guardID: guardID, jwt: jwt, payload: signPayload, algorithm: algorithm)
    )
    return signature
  }
}
