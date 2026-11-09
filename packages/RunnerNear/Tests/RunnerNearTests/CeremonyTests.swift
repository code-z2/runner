//
//  CeremonyTests.swift
//  RunnerNearTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNearTesting
import Testing

@testable import RunnerNear

struct CeremonyTests {

  private func provider() -> Auth0PasskeyProvider {
    Auth0PasskeyProvider(
      network: NearNetwork.testnet(relayerURL: URL(string: "https://relayer.test")!),
      transport: MockAuthTransport()
    )
  }

  private func jwt(payload: String) -> String {
    func b64(_ json: String) -> String {
      Data(json.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    }
    return b64(#"{"alg":"RS256"}"#) + "." + b64(payload) + ".sig"
  }

  @Test
  func signatureURLCarriesPayloadAndScope() throws {
    let payload = Data([1, 2, 3, 250])
    let url = try provider().authorizeSignatureURL(
      payload: .nep413(payload),
      redirectURI: "runner://auth",
      state: "s1",
      codeChallenge: "challenge"
    )
    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func value(_ name: String) -> String? {
      query.first(where: { $0.name == name })?.value
    }
    #expect(value("scope") == "transaction:sign")
    #expect(value("audience") == "auth0.jwt.fast-auth.testnet")
    // Comma-joined bytes, exactly like the JS/RN providers: the tenant
    // Action splits the parameter on "," and denies anything else.
    #expect(value("nep413") == "1,2,3,250")
  }

  @Test
  func fatxnDecodesByteArrays() throws {
    let token = jwt(payload: #"{"sub":"auth0|abc","exp":9999999999,"fatxn":{"nep413":[1,2,250]}}"#)
    let bytes = try provider().fatxnPayload(jwt: token)
    #expect(Array(bytes) == [1, 2, 250])
  }

  @Test
  func fatxnMissingFailsClosed() throws {
    let token = jwt(payload: #"{"sub":"auth0|abc","exp":9999999999}"#)
    #expect(throws: NearError.self) {
      try provider().fatxnPayload(jwt: token)
    }
  }

  @Test
  func derivationPathFormat() {
    #expect(
      MpcAccountResolver.derivationPath(
        authDomain: "login.testnet.fast-auth.com",
        subject: "auth0|abc"
      ) == "jwt#https://login.testnet.fast-auth.com/#auth0|abc")
  }

  @Test
  func resolverComposesPathKeyAndAccount() async throws {
    let rpc = MockNearRpc()
    await rpc.scriptMpcKey(
      path: "jwt#https://login.testnet.fast-auth.com/#auth0|abc",
      value: "ed25519:FVen3X669xLzsi6N2V91DoiyzHzg1uAgqiT8jZ9nS96Z"
    )
    let mock = MockNearCore()
    mock.scriptAccountID(
      "5e64594046f2cbf53c1cbd2956830ef8efe05d29ef9eb639ab0ff8dacf2607e4")
    let resolver = MpcAccountResolver(
      network: NearNetwork.testnet(relayerURL: URL(string: "https://relayer.test")!),
      rpc: rpc,
      core: mock
    )
    let session = PasskeySession(
      idToken: "jwt",
      refreshToken: nil,
      expiresAt: Date().addingTimeInterval(3600),
      subject: "auth0|abc"
    )
    let account = try await resolver.resolve(session: session)
    #expect(account.publicKey == "ed25519:FVen3X669xLzsi6N2V91DoiyzHzg1uAgqiT8jZ9nS96Z")
    #expect(account.accountID == "5e64594046f2cbf53c1cbd2956830ef8efe05d29ef9eb639ab0ff8dacf2607e4")
  }
}
