//
//  AuthFlowTests.swift
//  RunnerTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerAuth
import RunnerAuthTesting
import RunnerNear
import RunnerNearTesting
import Testing

@testable import Runner

struct AuthFlowTests {

  private func appleJWT(nonce: String) -> String {
    func b64(_ json: String) -> String {
      Data(json.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    }
    let payload: [String: Any] = [
      "iss": "https://appleid.apple.com", "aud": "app.runner", "sub": "apple-user-1",
      "exp": 9_999_999_999, "nonce": nonce,
    ]
    let body = String(data: try! JSONSerialization.data(withJSONObject: payload), encoding: .utf8)!
    return b64(#"{"alg":"ES256"}"#) + "." + b64(body) + ".sig"
  }

  private func nearJWT(sub: String = "auth0|abc", fatxn: String? = nil) -> String {
    func b64(_ json: String) -> String {
      Data(json.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    }
    var payload = #"{"sub":"\#(sub)","exp":9999999999}"#
    if let fatxn { payload = #"{"sub":"\#(sub)","exp":9999999999,"fatxn":\#(fatxn)}"# }
    return b64(#"{"alg":"RS256"}"#) + "." + b64(payload) + ".sig"
  }

  private func flow(
    transport: MockAuthTransport = MockAuthTransport(),
    coordinator: RunnerAuthCoordinator? = nil,
    resolve: @escaping @Sendable (PasskeySession) async throws -> NearAccount = {
      _ in NearAccount(accountID: "a.near", publicKey: "k")
    }
  ) -> (AuthFlow, RunnerAuthCoordinator, MockAuthTransport) {
    let store = MemoryStore()
    let auth = coordinator ?? RunnerAuthCoordinator(store: store)
    let provider = Auth0PasskeyProvider(
      network: NearNetwork.testnet(relayerURL: URL(string: "https://relay.test")!),
      transport: transport)
    let flow = AuthFlow(
      provider: provider,
      coordinator: auth,
      redirectURI: "https://ije.wades.io/auth/callback",
      appleAudience: "app.runner",
      resolveAccount: resolve)
    return (flow, auth, transport)
  }

  @Test
  func appleRoundTripLinksIdentity() async throws {
    let (flow, auth, _) = flow()
    let requestHash = await flow.beginApple()
    let identity = try await flow.completeApple(identityToken: appleJWT(nonce: requestHash))
    #expect(identity.userID == "apple-user-1")
    let account = try await auth.current()
    #expect(account?.apple.userID == "apple-user-1")
  }

  @Test
  func appleWithoutBeginFailsClosed() async throws {
    let (flow, _, _) = flow()
    // NOTE: no `#expect(throws: AuthError.self)` or `catch as AuthError`
    // here. The package links statically into both the app and the test
    // bundle, so the thrown value's runtime metadata is a different
    // object than this image's `AuthError.self` and every type-identity
    // check rejects it. The NSError domain (module-qualified type name)
    // plus code (case discriminator) are identical in both images, so
    // they still branch on the case instead of on text.
    do {
      try await flow.completeApple(identityToken: self.appleJWT(nonce: "x"))
      Issue.record("completeApple without beginApple must throw")
    } catch {
      let actual = error as NSError
      let expected = AuthError.noSession as NSError
      #expect(actual.domain == expected.domain)
      #expect(actual.code == expected.code)
    }
  }

  @Test
  func loginRoundTripLinksNear() async throws {
    let (flow, auth, transport) = flow()
    try await auth.linkApple(
      AppleIdentity(
        userID: "u", email: nil, givenName: nil, familyName: nil, identityToken: "t"))
    await transport.enqueue(json: #"{"id_token":"\#(nearJWT())","expires_in":3600}"#)
    let url = try await flow.beginLogin()
    #expect(url.host == "login.testnet.fast-auth.com")
    let callback = URL(
      string:
        "https://ije.wades.io/auth/callback?code=c&state=\(state(of: url))"
    )!
    let session = try await flow.completeLoginCallback(callback)
    #expect(session.subject == "auth0|abc")
    let account = try await auth.current()
    #expect(account?.near?.account.accountID == "a.near")
  }

  @Test
  func loginStateMismatchFails() async throws {
    let (flow, _, _) = flow()
    _ = try await flow.beginLogin()
    let callback = URL(string: "https://ije.wades.io/auth/callback?code=c&state=tampered")!
    await #expect(throws: AuthCallbackError.self) {
      try await flow.completeLoginCallback(callback)
    }
  }

  @Test
  func signatureCeremonyLinksAccount() async throws {
    let (flow, auth, transport) = flow()
    try await auth.linkApple(
      AppleIdentity(
        userID: "u", email: nil, givenName: nil, familyName: nil, identityToken: "t"))
    await transport.enqueue(
      json: #"{"access_token":"\#(nearJWT(fatxn: "[1,2]"))","expires_in":60}"#)
    let url = try await flow.beginSignature(payload: .transaction(Data([1, 2])))
    #expect(url.absoluteString.contains("transaction=1,2"))
    let callback = URL(
      string:
        "https://ije.wades.io/auth/callback?code=c&state=\(state(of: url))"
    )!
    let account = try await flow.completeSignatureCallback(callback)
    #expect(account.accountID == "a.near")
    let current = try await auth.current()
    #expect(current?.near?.idToken == nearJWT(fatxn: "[1,2]"))
  }

  private func state(of url: URL) -> String {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "state" })?.value ?? "missing"
  }
}
