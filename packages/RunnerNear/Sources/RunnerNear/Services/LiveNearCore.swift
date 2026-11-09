//
//  LiveNearCore.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

/// Production core: thin delegation to the UniFFI bindings with
/// generated errors mapped once to `NearError`.
import RunnerNearCore

public struct LiveNearCore: NearCoreFunctions, Sendable {

  public init() {}

  public func nep413DigestHex(
    message: String,
    nonceBase64: String,
    recipient: String
  ) throws -> String {
    try map {
      try RunnerNearCore.nep413DigestHex(
        message: message, nonceB64: nonceBase64, recipient: recipient)
    }
  }

  public func ed25519Keypair() throws -> NearKeypair {
    let pair = try map { try RunnerNearCore.ed25519Keypair() }
    return NearKeypair(secretBase64: pair.secretB64, publicKey: pair.publicKey)
  }

  public func ed25519Sign(secretBase64: String, messageHex: String) throws -> String {
    try map { try RunnerNearCore.ed25519Sign(secretB64: secretBase64, messageHex: messageHex) }
  }

  public func ed25519Verify(
    publicKey: String,
    messageHex: String,
    signatureBase64: String
  ) throws -> Bool {
    try map {
      try RunnerNearCore.ed25519Verify(
        publicKey: publicKey,
        messageHex: messageHex,
        signatureB64: signatureBase64
      )
    }
  }

  public func implicitAccountID(publicKey: String) throws -> String {
    try map { try RunnerNearCore.implicitAccountId(publicKey: publicKey) }
  }

  public func buildTransferTx(
    sender: String,
    receiver: String,
    publicKey: String,
    nonce: UInt64,
    blockHashHex: String,
    amountYocto: String
  ) throws -> String {
    try map {
      try RunnerNearCore.buildUnsignedTx(
        sender: sender,
        receiver: receiver,
        publicKey: publicKey,
        nonce: nonce,
        blockHashHex: blockHashHex,
        action: .transfer(amountYocto: amountYocto)
      )
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
    try map {
      try RunnerNearCore.buildUnsignedTx(
        sender: sender,
        receiver: receiver,
        publicKey: publicKey,
        nonce: nonce,
        blockHashHex: blockHashHex,
        action: .functionCall(
          method: method,
          argsJson: argsJSON,
          gas: gas,
          depositYocto: depositYocto
        )
      )
    }
  }

  public func txSigningHash(unsignedBase64: String) throws -> String {
    try map { try RunnerNearCore.txSigningHash(unsignedB64: unsignedBase64) }
  }

  public func attachSignature(unsignedBase64: String, signatureBase64: String, publicKey: String)
    throws -> String
  {
    try map {
      try RunnerNearCore.attachSignature(
        unsignedB64: unsignedBase64,
        signatureB64: signatureBase64,
        publicKey: publicKey
      )
    }
  }

  static func mapCore(_ error: RunnerNearCore.CoreError) -> NearError {
    switch error {
    case .InvalidInput(let message):
      return NearError.invalidInput(message)
    case .Crypto(let message):
      return NearError.crypto(message)
    case .Transport(let message):
      return NearError.transport(message)
    case .Chain(let code, let detail):
      return NearError.chain(code: code, detail: detail)
    }
  }

  private func map<T>(_ work: () throws -> T) throws -> T {
    do {
      return try work()
    } catch let error as RunnerNearCore.CoreError {
      throw Self.mapCore(error)
    }
  }
}
