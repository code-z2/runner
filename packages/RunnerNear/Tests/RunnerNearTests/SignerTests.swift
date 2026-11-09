//
//  SignerTests.swift
//  RunnerNearTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNearTesting
import Testing

@testable import RunnerNear

struct StaticProvider: PasskeyProvider, Sendable {

  let fixed: PasskeySession?

  func authorizeURL(redirectURI: String, state: String, codeChallenge: String) throws -> URL {
    URL(string: "https://example.com")!
  }

  func completeLogin(callbackURL: URL, codeVerifier: String, redirectURI: String) async throws
    -> PasskeySession
  {
    throw NearError.notLoggedIn
  }

  func session() async throws -> PasskeySession? { fixed }

  func logout() async {}

  func authorizeSignatureURL(
    payload: SignaturePayload,
    redirectURI: String,
    state: String,
    codeChallenge: String
  ) throws -> URL {
    URL(string: "https://example.com/sign")!
  }

  func completeSignatureCallback(
    _ url: URL,
    codeVerifier: String,
    redirectURI: String,
    expectedPayloadHex: String
  ) async throws -> String {
    throw NearError.notLoggedIn
  }

  func fatxnPayload(jwt: String) throws -> Data {
    // Real decode logic, no network: the ceremony's safety net is production code.
    let provider = Auth0PasskeyProvider(
      network: NearNetwork.testnet(relayerURL: URL(string: "https://relayer.test")!),
      transport: MockAuthTransport()
    )
    return try provider.fatxnPayload(jwt: jwt)
  }
}

struct SignerTests {

  private func jwt(sub: String = "auth0|abc", exp: Int? = nil, fatxn: String? = nil) -> String {
    func b64(_ json: String) -> String {
      Data(json.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    }
    let expiry = exp ?? Int(Date().timeIntervalSince1970) + 3600
    var payload = #"{"sub":"\#(sub)","exp":\#(expiry)"#
    if let fatxn { payload += #","fatxn":\#(fatxn)"# }
    payload += "}"
    return b64(#"{"alg":"RS256"}"#) + "." + b64(payload) + ".sig"
  }

  private func signer(
    core: any NearCoreFunctions = LiveNearCore(),
    relayer: MockSignSubmitter = MockSignSubmitter(),
    rpc: MockNearRpc = MockNearRpc(),
    session: PasskeySession? = PasskeySession(
      idToken: "jwt-1",
      refreshToken: nil,
      expiresAt: Date().addingTimeInterval(3600),
      subject: "auth0|abc"
    )
  ) -> (FastAuthSigner, MockSignSubmitter) {
    let signer = FastAuthSigner(
      provider: StaticProvider(fixed: session),
      resolver: MockAccountResolver(
        account: NearAccount(accountID: "alice.testnet", publicKey: "ed25519:abc")
      ),
      core: core,
      rpc: rpc,
      submitter: relayer,
      network: NearNetwork.testnet(relayerURL: URL(string: "https://relayer.test")!)
    )
    return (signer, relayer)
  }

  private func digestHex(message: String, nonce: Data) throws -> String {
    try LiveNearCore().nep413DigestHex(
      message: message,
      nonceBase64: nonce.base64EncodedString(),
      recipient: "runner-api"
    )
  }

  private func fatxnJWT(hex: String) -> String {
    let bytes = stride(from: 0, to: hex.count, by: 2).map {
      Int(
        hex[hex.index(hex.startIndex, offsetBy: $0)..<hex.index(hex.startIndex, offsetBy: $0 + 2)],
        radix: 16)!
    }
    return jwt(fatxn: #"{"nep413":[\#(bytes.map(String.init).joined(separator: ","))]}"#)
  }

  @Test
  func nep413BuildsGuardedRequest() async throws {
    let (signer, relayer) = signer()
    let nonce = Data(repeating: 7, count: 32)
    let digest = try digestHex(message: "hello runner", nonce: nonce)
    let token = fatxnJWT(hex: digest)
    let signatureB64 = try await signer.signNep413(
      message: "hello runner",
      nonce: nonce,
      recipient: "runner-api",
      idToken: token
    )
    let submissions = await relayer.submissions
    #expect(submissions.count == 1)
    #expect(submissions[0].guardID == "jwt#https://login.testnet.fast-auth.com/")
    #expect(submissions[0].jwt == token)
    #expect(submissions[0].algorithm == .edwards)
    #expect(submissions[0].payload.map { String(format: "%02x", $0) }.joined() == digest)
    #expect(Data(base64Encoded: signatureB64)?.count == 64)
  }

  @Test
  func nep413RefusesForeignFatxn() async throws {
    let (signer, _) = signer()
    let nonce = Data(repeating: 7, count: 32)
    _ = try digestHex(message: "hello runner", nonce: nonce)
    // JWT bound to a DIFFERENT message.
    let other = try digestHex(message: "other", nonce: nonce)
    let token = fatxnJWT(hex: other)
    await #expect(throws: NearError.self) {
      try await signer.signNep413(
        message: "hello runner",
        nonce: nonce,
        recipient: "runner-api",
        idToken: token
      )
    }
  }

  @Test
  func nep413RejectsShortNonce() async throws {
    let (signer, _) = signer()
    await #expect(throws: NearError.self) {
      try await signer.signNep413(
        message: "m",
        nonce: Data(repeating: 0, count: 8),
        recipient: "r",
        idToken: "jwt"
      )
    }
  }

  @Test
  func guardIDFormat() {
    #expect(
      FastAuthSigner.guardID(authDomain: "login.testnet.fast-auth.com")
        == "jwt#https://login.testnet.fast-auth.com/")
  }

  @Test
  func accountComesFromResolver() async throws {
    let (signer, _) = signer()
    #expect(try await signer.account.accountID == "alice.testnet")
  }
}
