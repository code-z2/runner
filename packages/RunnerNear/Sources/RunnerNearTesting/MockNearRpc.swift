//
//  MockNearRpc.swift
//  RunnerNearTesting
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// Scripted RPC: canned answers, recorded calls. Live testnet behavior is
/// proven by the Rust `#[ignore]` tests, not here.
public actor MockNearRpc: NearRpcFunctions {

  private var block = RpcBlockRef(hashHex: String(repeating: "ab", count: 32), height: 1)
  private var keys: [String: RpcAccessKey] = [:]
  private var views: [String: Data] = [:]
  private var outcomes: [RpcTxOutcome] = []
  private var mpcKeys: [String: String] = [:]

  public private(set) var broadcasts: [String] = []

  public init() {}

  public func scriptBlock(_ value: RpcBlockRef) { block = value }
  public func scriptAccessKey(accountID: String, publicKey: String, value: RpcAccessKey) {
    keys[accountID + publicKey] = value
  }
  public func scriptView(contractID: String, method: String, argsJSON: String, value: Data) {
    views[contractID + method + argsJSON] = value
  }
  public func scriptBroadcast(_ value: RpcTxOutcome) { outcomes.append(value) }
  public func scriptMpcKey(path: String, value: String) { mpcKeys[path] = value }

  public func latestBlock() throws -> RpcBlockRef { block }

  public func accessKey(accountID: String, publicKey: String) throws -> RpcAccessKey {
    guard let key = keys[accountID + publicKey] else {
      throw NearError.chain(code: "unknown_access_key", detail: accountID)
    }
    return key
  }

  public func viewCall(contractID: String, method: String, argsJSON: String) throws -> Data {
    guard let data = views[contractID + method + argsJSON] else {
      throw NearError.transport("no view scripted")
    }
    return data
  }

  public func broadcastCommit(signedTxBase64: String) throws -> RpcTxOutcome {
    broadcasts.append(signedTxBase64)
    guard !outcomes.isEmpty else { throw NearError.transport("no outcome scripted") }
    return outcomes.removeFirst()
  }

  public func mpcPublicKey(mpcContract: String, fastAuthContract: String, path: String) throws
    -> String
  {
    guard let key = mpcKeys[path] else { throw NearError.transport("no mpc key scripted") }
    return key
  }
}
