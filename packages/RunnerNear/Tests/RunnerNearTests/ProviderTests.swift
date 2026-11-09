//
//  ProviderTests.swift
//  RunnerNearTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNearTesting
import Testing

@testable import RunnerNear

struct ProviderTests {

  private func network() -> NearNetwork {
    NearNetwork.testnet(relayerURL: URL(string: "https://relayer.test")!)
  }

  /// Unsigned JWT with a controllable exp. Signature never checked
  /// client-side — the MPC guard verifies it on-chain.
  private func jwt(exp: Int, sub: String = "auth0|abc") -> String {
    func b64(_ json: String) -> String {
      Data(json.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    }
    return b64(#"{"alg":"RS256"}"#) + "." + b64(#"{"sub":"\#(sub)","exp":\#(exp)}"#) + ".sig"
  }

  private func tokenJSON(idToken: String, refresh: String? = "refresh-1", expiresIn: Int = 3600)
    -> String
  {
    if let refresh {
      return #"{"id_token":"\#(idToken)","refresh_token":"\#(refresh)","expires_in":\#(expiresIn)}"#
    }
    return #"{"id_token":"\#(idToken)","expires_in":\#(expiresIn)}"#
  }

  @Test
  func authorizeURLTargetsTestnetTenant() throws {
    let provider = Auth0PasskeyProvider(network: network(), transport: MockAuthTransport())
    let url = try provider.authorizeURL(
      redirectURI: "runner://auth",
      state: "s1",
      codeChallenge: "challenge"
    )
    #expect(url.host == "login.testnet.fast-auth.com")
    #expect(url.path == "/authorize")
    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func value(_ name: String) -> String? {
      query.first(where: { $0.name == name })?.value
    }
    #expect(value("client_id") == "np8paqIpMWmNbzT4xAvOOapZBjsOpptl")
    #expect(value("audience") == "auth0.jwt.fast-auth.testnet")
    #expect(value("code_challenge_method") == "S256")
    #expect(value("redirect_uri") == "runner://auth")
  }

  @Test
  func completeLoginExchangesCode() async throws {
    let transport = MockAuthTransport()
    let provider = Auth0PasskeyProvider(network: network(), transport: transport)
    let future = Int(Date().timeIntervalSince1970) + 3600
    await transport.enqueue(json: tokenJSON(idToken: jwt(exp: future)))
    let session = try await provider.completeLogin(
      callbackURL: URL(string: "runner://auth?code=auth-code&state=s1")!,
      codeVerifier: "verifier",
      redirectURI: "runner://auth"
    )
    #expect(session.subject == "auth0|abc")
    #expect(!session.isExpired())
    let body = await transport.formBody(of: transport.requests[0])
    #expect(body["grant_type"] == "authorization_code")
    #expect(body["code"] == "auth-code")
    #expect(body["code_verifier"] == "verifier")
  }

  @Test
  func callbackWithoutCodeFails() async throws {
    let provider = Auth0PasskeyProvider(network: network(), transport: MockAuthTransport())
    await #expect(throws: NearError.self) {
      try await provider.completeLogin(
        callbackURL: URL(string: "runner://auth?state=s1")!,
        codeVerifier: "v",
        redirectURI: "runner://auth"
      )
    }
  }

  @Test
  func expiredSessionRefreshes() async throws {
    let transport = MockAuthTransport()
    let provider = Auth0PasskeyProvider(network: network(), transport: transport)
    let past = Int(Date().timeIntervalSince1970) - 10
    await transport.enqueue(json: tokenJSON(idToken: jwt(exp: past)))
    _ = try await provider.completeLogin(
      callbackURL: URL(string: "runner://auth?code=c1")!,
      codeVerifier: "v",
      redirectURI: "runner://auth"
    )
    let future = Int(Date().timeIntervalSince1970) + 7200
    await transport.enqueue(json: tokenJSON(idToken: jwt(exp: future), refresh: "refresh-2"))
    let session = try await provider.session()
    #expect(session?.refreshToken == "refresh-2")
    let body = await transport.formBody(of: transport.requests[1])
    #expect(body["grant_type"] == "refresh_token")
    #expect(body["refresh_token"] == "refresh-1")
  }

  @Test
  func expiredWithoutRefreshTokenFailsClosed() async throws {
    let transport = MockAuthTransport()
    let provider = Auth0PasskeyProvider(network: network(), transport: transport)
    let past = Int(Date().timeIntervalSince1970) - 10
    await transport.enqueue(json: tokenJSON(idToken: jwt(exp: past), refresh: nil))
    _ = try await provider.completeLogin(
      callbackURL: URL(string: "runner://auth?code=c1")!,
      codeVerifier: "v",
      redirectURI: "runner://auth"
    )
    await #expect(throws: NearError.self) {
      try await provider.session()
    }
  }

  @Test
  func oauthErrorSurfaces() async throws {
    let transport = MockAuthTransport()
    let provider = Auth0PasskeyProvider(network: network(), transport: transport)
    await transport.enqueue(json: #"{"error":"access_denied"}"#, status: 403)
    await #expect(throws: NearError.self) {
      try await provider.completeLogin(
        callbackURL: URL(string: "runner://auth?code=c1")!,
        codeVerifier: "v",
        redirectURI: "runner://auth"
      )
    }
  }

  @Test
  func logoutClearsSession() async throws {
    let transport = MockAuthTransport()
    let provider = Auth0PasskeyProvider(network: network(), transport: transport)
    let future = Int(Date().timeIntervalSince1970) + 3600
    await transport.enqueue(json: tokenJSON(idToken: jwt(exp: future)))
    _ = try await provider.completeLogin(
      callbackURL: URL(string: "runner://auth?code=c1")!,
      codeVerifier: "v",
      redirectURI: "runner://auth"
    )
    await provider.logout()
    #expect(try await provider.session() == nil)
  }
}
