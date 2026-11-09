//
//  LiveNearRpc.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNearCore

/// Production RPC: thin delegation to the Rust client, errors mapped once.
public struct LiveNearRpc: NearRpcFunctions, Sendable {

  private let inner: RunnerNearCore.NearRpc

  public init(rpcURL: String) throws {
    do {
      inner = try RunnerNearCore.NearRpc(rpcUrl: rpcURL)
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  public func latestBlock() throws -> RpcBlockRef {
    do {
      let block = try inner.latestBlock()
      return RpcBlockRef(hashHex: block.hashHex, height: block.height)
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  public func accessKey(accountID: String, publicKey: String) throws -> RpcAccessKey {
    do {
      let key = try inner.accessKey(accountId: accountID, publicKey: publicKey)
      return RpcAccessKey(nonce: key.nonce, fullAccess: key.fullAccess)
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  public func viewCall(contractID: String, method: String, argsJSON: String) throws -> Data {
    do {
      return try inner.viewCall(contractId: contractID, method: method, argsJson: argsJSON)
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  public func broadcastCommit(signedTxBase64: String) throws -> RpcTxOutcome {
    do {
      let outcome = try inner.broadcastCommit(signedTxB64: signedTxBase64)
      return RpcTxOutcome(
        txHashHex: outcome.txHashHex,
        success: outcome.success,
        failure: outcome.failure
      )
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  public func mpcPublicKey(mpcContract: String, fastAuthContract: String, path: String) throws
    -> String
  {
    do {
      return try inner.mpcPublicKey(
        mpcContract: mpcContract,
        fastAuthContract: fastAuthContract,
        path: path
      )
    } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }
}
