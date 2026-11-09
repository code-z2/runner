//
//  NearRpcFunctions.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// The seam over the Rust RPC client. Block data and outcomes cross as
/// typed records; view bytes stay raw.
public protocol NearRpcFunctions: Sendable {

  func latestBlock() async throws -> RpcBlockRef

  func accessKey(accountID: String, publicKey: String) async throws -> RpcAccessKey

  func viewCall(contractID: String, method: String, argsJSON: String) async throws -> Data

  func broadcastCommit(signedTxBase64: String) async throws -> RpcTxOutcome

  func mpcPublicKey(mpcContract: String, fastAuthContract: String, path: String) async throws
    -> String
}

public struct RpcBlockRef: Sendable, Equatable {
  public let hashHex: String
  public let height: UInt64
  public init(hashHex: String, height: UInt64) {
    self.hashHex = hashHex
    self.height = height
  }
}

public struct RpcAccessKey: Sendable, Equatable {
  public let nonce: UInt64
  public let fullAccess: Bool
  public init(nonce: UInt64, fullAccess: Bool) {
    self.nonce = nonce
    self.fullAccess = fullAccess
  }
}

public struct RpcTxOutcome: Sendable, Equatable {
  public let txHashHex: String
  public let success: Bool
  public let failure: String?
  public init(txHashHex: String, success: Bool, failure: String?) {
    self.txHashHex = txHashHex
    self.success = success
    self.failure = failure
  }
}
