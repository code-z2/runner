//
//  MockNearCore.swift
//  RunnerNearTesting
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// Scripted core: canned answers per function, recorded calls.
/// Anything unscripted throws — tests must say what the core says.
public final class MockNearCore: NearCoreFunctions, Sendable {

  private let locked = Locked<State>(State())

  public init() {}

  public func scriptNep413(_ value: String) {
    locked.with { $0.nep413 = value }
  }

  public func scriptVerify(_ value: Bool) {
    locked.with { $0.verify = value }
  }

  public func scriptKeypair(_ value: NearKeypair) {
    locked.with { $0.keypair = value }
  }

  public func scriptSignature(_ value: String) {
    locked.with { $0.signature = value }
  }

  public func scriptAccountID(_ value: String) {
    locked.with { $0.accountID = value }
  }

  public func scriptUnsignedTx(_ value: String) {
    locked.with { $0.unsignedTx = value }
  }

  public func scriptTxHash(_ value: String) {
    locked.with { $0.txHash = value }
  }

  public func scriptSignedTx(_ value: String) {
    locked.with { $0.signedTx = value }
  }

  public func scriptDelegate(_ value: String) {
    locked.with { $0.delegate = value }
  }

  public func scriptDelegateDigest(_ value: String) {
    locked.with { $0.delegateDigest = value }
  }

  public func scriptSignedDelegate(_ value: String) {
    locked.with { $0.delegateSigned = value }
  }

  public var recordedNep413Inputs: [(String, String, String)] {
    locked.with { $0.nep413Inputs }
  }

  public func nep413DigestHex(message: String, nonceBase64: String, recipient: String) throws
    -> String
  {
    locked.with { $0.nep413Inputs.append((message, nonceBase64, recipient)) }
    return try locked.with {
      guard let value = $0.nep413 else { throw NearError.invalidInput("no nep413 scripted") }
      return value
    }
  }

  public func ed25519Keypair() throws -> NearKeypair {
    try locked.with {
      guard let value = $0.keypair else { throw NearError.invalidInput("no keypair scripted") }
      return value
    }
  }

  public func ed25519Sign(secretBase64: String, messageHex: String) throws -> String {
    try locked.with {
      guard let value = $0.signature else { throw NearError.invalidInput("no signature scripted") }
      return value
    }
  }

  public func ed25519Verify(publicKey: String, messageHex: String, signatureBase64: String) throws
    -> Bool
  {
    try locked.with {
      guard let value = $0.verify else { throw NearError.invalidInput("no verify scripted") }
      return value
    }
  }

  public func implicitAccountID(publicKey: String) throws -> String {
    try locked.with {
      guard let value = $0.accountID else { throw NearError.invalidInput("no account id scripted") }
      return value
    }
  }

  public func buildTransferTx(
    sender: String,
    receiver: String,
    publicKey: String,
    nonce: UInt64,
    blockHashHex: String,
    amountYocto: String
  ) throws -> String {
    try locked.with {
      guard let value = $0.unsignedTx else {
        throw NearError.invalidInput("no unsigned tx scripted")
      }
      $0.txInputs.append((sender, receiver, publicKey, nonce, blockHashHex, amountYocto, nil))
      return value
    }
  }

  public func buildFunctionCallTx(
    sender: String,
    receiver: String,
    publicKey: String,
    nonce: UInt64,
    blockHashHex: String,
    method: String,
    argsJSON: String,
    gas: UInt64,
    depositYocto: String
  ) throws -> String {
    try locked.with {
      guard let value = $0.unsignedTx else {
        throw NearError.invalidInput("no unsigned tx scripted")
      }
      $0.txInputs.append((sender, receiver, publicKey, nonce, blockHashHex, "", method))
      return value
    }
  }

  public func txSigningHash(unsignedBase64: String) throws -> String {
    try locked.with {
      guard let value = $0.txHash else { throw NearError.invalidInput("no tx hash scripted") }
      return value
    }
  }

  public func attachSignature(unsignedBase64: String, signatureBase64: String, publicKey: String)
    throws -> String
  {
    try locked.with {
      guard let value = $0.signedTx else {
        throw NearError.invalidInput("no signed tx scripted")
      }
      return value
    }
  }

  public func encodeDelegateAction(
    senderID: String,
    receiverID: String,
    methodName: String,
    argsJSON: String,
    gas: UInt64,
    depositYocto: String,
    nonce: UInt64,
    maxBlockHeight: UInt64,
    publicKey: String
  ) throws -> String {
    try locked.with {
      guard let value = $0.delegate else {
        throw NearError.invalidInput("no delegate scripted")
      }
      $0.delegateInputs.append(
        (
          senderID, receiverID, methodName, argsJSON, gas, depositYocto, nonce, maxBlockHeight,
          publicKey
        ))
      return value
    }
  }

  public func nep366DigestHex(delegateB64: String) throws -> String {
    try locked.with {
      guard let value = $0.delegateDigest else {
        throw NearError.invalidInput("no delegate digest scripted")
      }
      return value
    }
  }

  public func encodeSignedDelegate(delegateB64: String, signatureB64: String) throws -> String {
    try locked.with {
      guard let value = $0.delegateSigned else {
        throw NearError.invalidInput("no signed delegate scripted")
      }
      return value
    }
  }

  public var recordedDelegateInputs:
    [(String, String, String, String, UInt64, String, UInt64, UInt64, String)]
  {
    locked.with { $0.delegateInputs }
  }

  private struct State {
    var nep413: String?
    var nep413Inputs: [(String, String, String)] = []
    var keypair: NearKeypair?
    var signature: String?
    var verify: Bool?
    var accountID: String?
    var unsignedTx: String?
    var txHash: String?
    var signedTx: String?
    var txInputs: [(String, String, String, UInt64, String, String, String?)] = []
    var delegate: String?
    var delegateDigest: String?
    var delegateSigned: String?
    var delegateInputs: [(String, String, String, String, UInt64, String, UInt64, UInt64, String)] =
      []
  }

  private final class Locked<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()
    init(_ value: T) { self.value = value }
    func with<R>(_ work: (inout T) throws -> R) rethrows -> R {
      lock.lock()
      defer { lock.unlock() }
      return try work(&value)
    }
  }
}
