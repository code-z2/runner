//
//  NearCoreFunctions.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

/// The seam over `runner-near-core`. Swift never calls generated
/// bindings directly outside `LiveNearCore` — tests swap in `MockNearCore`.
public protocol NearCoreFunctions: Sendable {

  func nep413DigestHex(message: String, nonceBase64: String, recipient: String) throws -> String

  func ed25519Keypair() throws -> NearKeypair

  func ed25519Sign(secretBase64: String, messageHex: String) throws -> String

  func ed25519Verify(publicKey: String, messageHex: String, signatureBase64: String) throws -> Bool

  func implicitAccountID(publicKey: String) throws -> String

  func buildTransferTx(
    sender: String,
    receiver: String,
    publicKey: String,
    nonce: UInt64,
    blockHashHex: String,
    amountYocto: String
  ) throws -> String

  func buildFunctionCallTx(
    sender: String,
    receiver: String,
    publicKey: String,
    nonce: UInt64,
    blockHashHex: String,
    method: String,
    argsJSON: String,
    gas: UInt64,
    depositYocto: String
  ) throws -> String

  func txSigningHash(unsignedBase64: String) throws -> String

  func attachSignature(unsignedBase64: String, signatureBase64: String, publicKey: String) throws
    -> String

  func encodeDelegateAction(
    senderID: String,
    receiverID: String,
    methodName: String,
    argsJSON: String,
    gas: UInt64,
    depositYocto: String,
    nonce: UInt64,
    maxBlockHeight: UInt64,
    publicKey: String
  ) throws -> String

  func nep366DigestHex(delegateB64: String) throws -> String

  func encodeSignedDelegate(delegateB64: String, signatureB64: String) throws -> String
}
