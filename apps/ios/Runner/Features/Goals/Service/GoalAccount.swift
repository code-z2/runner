import CryptoKit
import DeviceCheck
import Foundation
import RunnerAuth
import RunnerEscrow
import RunnerGateway
import RunnerNear

nonisolated enum GoalAccountError: Error {
  case attestationUnavailable
  case invalidChallenge
  case invalidDeviceRegistration
  case accessKeyUnavailable
}

/// The runner's device-held NEAR implicit account and App Attest key.
/// Signs Worker requests (NEP-413 + assertion), asserts 1Click proxy
/// bodies, and submits escrow calls as relayed delegates. The private key
/// stays in this device's Keychain.
actor GoalAccount: EscrowSubmitter {
  private let gateway: any GatewayClient
  private let core: any NearCoreFunctions
  private let rpc: any NearRpcFunctions
  private let keychain: any SecureStore
  private let deployment: EscrowDeployment
  private let attestationKey = "goals.device-attest-key"
  private let identityKey = "goals.near-identity"

  init(
    gateway: any GatewayClient, core: any NearCoreFunctions, rpc: any NearRpcFunctions,
    keychain: any SecureStore, deployment: EscrowDeployment
  ) {
    self.gateway = gateway
    self.core = core
    self.rpc = rpc
    self.keychain = keychain
    self.deployment = deployment
  }

  var accountID: String {
    get async throws { try await identity().accountID }
  }

  /// A Worker request signed for `action`, with `fields` merged into the payload.
  func signed<Fields: Encodable>(action: String?, fields: Fields) async throws -> ClaimPassRequest {
    let identity = try await identity()
    let key = try await deviceKey()
    let challenge = try await gateway.challenge().value
    guard Data(base64Encoded: challenge)?.count == 32 else {
      throw GoalAccountError.invalidChallenge
    }
    let payload = try encode(
      Payload(accountID: identity.accountID, challenge: challenge, action: action, fields: fields))
    let digest = try core.nep413DigestHex(
      message: payload, nonceBase64: challenge, recipient: "runner-api")
    let signature = try core.ed25519Sign(secretBase64: identity.secret, messageHex: digest)
    return ClaimPassRequest(
      payload: payload, keyID: key, assertion: try await assertion(payload, key: key),
      nearPublicKey: identity.publicKey, nearSignature: signature)
  }

  /// App Attest proof over `clientData` (the 1Click proxy request).
  func assert(_ clientData: String) async throws -> DeviceAssertion {
    let key = try await deviceKey()
    return DeviceAssertion(keyID: key, assertion: try await assertion(clientData, key: key))
  }

  /// Sign `call` as a NEP-366 delegate and submit it through `/v1/relay`.
  func submit(_ call: EscrowCall) async throws -> EscrowReceipt {
    let identity = try await identity()
    try await seed(identity)
    let function = try call.functionCall(on: deployment)
    let access = try await rpc.accessKey(
      accountID: identity.accountID, publicKey: identity.publicKey)
    let block = try await rpc.latestBlock()
    let (nonce, nonceOverflow) = access.nonce.addingReportingOverflow(1)
    let (maxBlockHeight, blockOverflow) = block.height.addingReportingOverflow(50)
    guard access.fullAccess, !nonceOverflow, !blockOverflow else {
      throw GoalAccountError.accessKeyUnavailable
    }
    let delegate = try core.encodeDelegateAction(
      senderID: identity.accountID, receiverID: function.receiverID, methodName: function.method,
      argsJSON: function.argsJSON, gas: 100_000_000_000_000, depositYocto: function.depositYocto,
      nonce: nonce, maxBlockHeight: maxBlockHeight, publicKey: identity.publicKey)
    let digest = try core.nep366DigestHex(delegateB64: delegate)
    let signature = try core.ed25519Sign(secretBase64: identity.secret, messageHex: digest)
    let signedDelegate = try core.encodeSignedDelegate(
      delegateB64: delegate, signatureB64: signature)
    let key = try await deviceKey()
    let result = try await gateway.relay(
      RelayRequest(
        signedDelegateB64: signedDelegate, keyID: key,
        assertionB64: try await assertion(signedDelegate, key: key)))
    guard result.status != .failed else {
      throw EscrowError.submitFailed(result.transactionHash)
    }
    return EscrowReceipt(reference: result.transactionHash)
  }

  // MARK: - Private

  private func identity() async throws -> Identity {
    if let identity = try await keychain.load(forKey: identityKey) {
      return try JSONDecoder().decode(Identity.self, from: identity)
    }
    let pair = try core.ed25519Keypair()
    let identity = Identity(
      accountID: try core.implicitAccountID(publicKey: pair.publicKey),
      publicKey: pair.publicKey, secret: pair.secretBase64)
    try await keychain.save(JSONEncoder().encode(identity), forKey: identityKey)
    return identity
  }

  private func deviceKey() async throws -> String {
    guard DCAppAttestService.shared.isSupported else {
      throw GoalAccountError.attestationUnavailable
    }
    if let data = try await keychain.load(forKey: attestationKey) {
      return String(decoding: data, as: UTF8.self)
    }
    let challenge = try await gateway.challenge().value
    guard let bytes = Data(base64Encoded: challenge), bytes.count == 32 else {
      throw GoalAccountError.invalidChallenge
    }
    let key = try await DCAppAttestService.shared.generateKey()
    let attestation = try await DCAppAttestService.shared.attestKey(
      key, clientDataHash: Data(SHA256.hash(data: bytes)))
    let registered = try await gateway.registerDevice(
      DeviceRegistration(
        keyID: key, attestation: attestation.base64EncodedString(), challenge: challenge))
    guard registered == key else { throw GoalAccountError.invalidDeviceRegistration }
    try await keychain.save(Data(key.utf8), forKey: attestationKey)
    return key
  }

  private func assertion(_ clientData: String, key: String) async throws -> String {
    let hash = Data(SHA256.hash(data: Data(clientData.utf8)))
    do {
      return try await DCAppAttestService.shared.generateAssertion(key, clientDataHash: hash)
        .base64EncodedString()
    } catch let error as DCError where error.code == .invalidKey {
      // App Attest keys can disappear on reinstall. Only reset that
      // credential; the NEAR account still owns its escrow.
      try await keychain.delete(forKey: attestationKey)
      throw error
    }
  }

  /// Fund the implicit account before its first delegate. Idempotent.
  private func seed(_ identity: Identity) async throws {
    let key = try await deviceKey()
    let payload = "seed:\(identity.accountID)"
    let hex = payload.utf8.map { String(format: "%02x", $0) }.joined()
    let signature = try core.ed25519Sign(secretBase64: identity.secret, messageHex: hex)
    _ = try await gateway.seed(
      SeedRequest(
        accountID: identity.accountID, keyID: key,
        assertion: try await assertion(payload, key: key),
        nearPublicKey: identity.publicKey, nearSignature: signature))
  }

  private func encode<Value: Encodable>(_ value: Value) throws -> String {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }

  private struct Identity: Codable {
    let accountID: String
    let publicKey: String
    let secret: String
  }

  /// The common signed keys plus the action-specific fields, as one object.
  private struct Payload<Fields: Encodable>: Encodable {
    let accountID: String
    let challenge: String
    let action: String?
    let fields: Fields

    private enum CodingKeys: String, CodingKey { case accountID, challenge, action }

    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(accountID, forKey: .accountID)
      try container.encode(challenge, forKey: .challenge)
      try container.encodeIfPresent(action, forKey: .action)
      try fields.encode(to: encoder)
    }
  }
}
