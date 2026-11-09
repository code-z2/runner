//
//  Auth0PasskeyProvider.swift
//  RunnerNear
//
//  Created by Peter on 09/11/2026.
//

import Foundation

/// Auth0 login scoped to passkeys. Builds the PKCE authorize URL, trades
/// the callback code for tokens, and refreshes silently. The hosted page
/// is the only UI and it belongs to Auth0 — no social buttons are ever
/// requested, and none are configured on this tenant for the app.
public actor Auth0PasskeyProvider: PasskeyProvider {

  private let network: NearNetwork
  private let transport: any AuthTransport
  private let clock: @Sendable () -> Date
  private var stored: PasskeySession?

  public init(
    network: NearNetwork,
    transport: any AuthTransport,
    clock: @escaping @Sendable () -> Date = Date.init
  ) {
    self.network = network
    self.transport = transport
    self.clock = clock
  }

  public nonisolated func authorizeURL(
    redirectURI: String,
    state: String,
    codeChallenge: String
  ) throws -> URL {
    var components = URLComponents()
    components.scheme = "https"
    components.host = network.authDomain
    components.path = "/authorize"
    components.queryItems = [
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "client_id", value: network.authClientID),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
      // No audience: plain login must not request the signing audience —
      // the tenant denies audience-without-payload, and a session login
      // carries no signing payload by design.
      URLQueryItem(name: "scope", value: "openid profile email offline_access"),
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
    ]
    guard let url = components.url else {
      throw NearError.invalidInput("unbuildable authorize URL")
    }
    return url
  }

  public func completeLogin(
    callbackURL: URL,
    codeVerifier: String,
    redirectURI: String
  ) async throws -> PasskeySession {
    let code = try callbackCode(from: callbackURL)
    let session = try await exchange(
      [
        "grant_type": "authorization_code", "code": code, "code_verifier": codeVerifier,
        "redirect_uri": redirectURI,
      ]
    )
    stored = session
    return session
  }

  public func session() async throws -> PasskeySession? {
    guard var current = stored else { return nil }
    if current.isExpired(now: clock()) {
      guard current.refreshToken != nil else { throw NearError.tokenExpired }
      current = try await exchange([
        "grant_type": "refresh_token", "refresh_token": current.refreshToken!,
      ])
      stored = current
    }
    return current
  }

  public func logout() {
    stored = nil
  }

  public nonisolated func authorizeSignatureURL(
    payload: SignaturePayload,
    redirectURI: String,
    state: String,
    codeChallenge: String
  ) throws -> URL {
    var components = URLComponents()
    components.scheme = "https"
    components.host = network.authDomain
    components.path = "/authorize"
    components.queryItems = [
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "client_id", value: network.authClientID),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
      URLQueryItem(name: "scope", value: "transaction:sign"),
      URLQueryItem(name: "audience", value: network.signingAudience),
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      // The payload rides as a login parameter, comma-joined bytes exactly
      // like the JS/RN providers (`number[].toString()`); NEAR's Auth0
      // Action splits on "," and denies anything else. The Action binds it
      // into the JWT's `fatxn` claim — `completeSignatureCallback` refuses
      // any JWT whose fatxn disagrees.
      URLQueryItem(
        name: payload.parameterName,
        value: payload.bytes.map { String($0) }.joined(separator: ",")),
    ]
    guard let url = components.url else {
      throw NearError.invalidInput("unbuildable signature URL")
    }
    return url
  }

  public func completeSignatureCallback(
    _ url: URL,
    codeVerifier: String,
    redirectURI: String,
    expectedPayloadHex: String
  ) async throws -> String {
    let code = try callbackCode(from: url)
    let session = try await exchange(
      [
        "grant_type": "authorization_code", "code": code, "code_verifier": codeVerifier,
        "redirect_uri": redirectURI,
      ]
    )
    let bound = try fatxnPayload(jwt: session.idToken)
    guard bound.map({ String(format: "%02x", $0) }).joined() == expectedPayloadHex.lowercased()
    else {
      throw NearError.fatxnMismatch
    }
    return session.idToken
  }

  public nonisolated func fatxnPayload(jwt: String) throws -> Data {
    let claims = try jwtClaims(jwt)
    guard let fatxn = claims["fatxn"] as? [String: Any] else {
      throw NearError.loginFailed("JWT carries no fatxn claim")
    }
    // One of transaction / delegateAction / nep413, as byte arrays.
    for key in ["transaction", "delegateAction", "nep413"] {
      if let numbers = fatxn[key] as? [Int] {
        return Data(numbers.compactMap { UInt8(exactly: $0) })
      }
      if let numbers = fatxn[key] as? [NSNumber] {
        return Data(numbers.compactMap { UInt8(exactly: $0.uint8Value) })
      }
    }
    throw NearError.loginFailed("fatxn carries no payload")
  }

  // MARK: - Plumbing

  private func callbackCode(from url: URL) throws -> String {
    guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
      let code = items.first(where: { $0.name == "code" })?.value,
      !code.isEmpty
    else {
      throw NearError.loginFailed("callback carried no code")
    }
    return code
  }

  private func tokenURL() throws -> URL {
    guard let url = URL(string: "https://\(network.authDomain)/oauth/token") else {
      throw NearError.invalidInput("bad auth domain")
    }
    return url
  }

  private func exchange(_ fields: [String: String]) async throws -> PasskeySession {
    var body = ["client_id": network.authClientID]
    for (key, value) in fields { body[key] = value }
    var request = URLRequest(url: try tokenURL())
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
    request.httpBody =
      body
      .map {
        "\($0.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)"
      }
      .joined(separator: "&")
      .data(using: .utf8)
    let (data, status): (Data, Int)
    do {
      (data, status) = try await transport.send(request)
    } catch {
      throw NearError.transport(String(describing: error))
    }
    guard status == 200 else {
      throw NearError.loginFailed(oauthCode(from: data) ?? "http \(status)")
    }
    return try decodeSession(data)
  }

  private func oauthCode(from data: Data) -> String? {
    (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
  }

  private func decodeSession(_ data: Data) throws -> PasskeySession {
    struct TokenResponse: Decodable {
      let idToken: String?
      let accessToken: String?
      let refreshToken: String?
      let expiresIn: Int
      private enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
      }
    }
    let decoded: TokenResponse
    do {
      decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
    } catch {
      throw NearError.loginFailed("unreadable token response")
    }
    // Session login returns an id_token; a signing-audience exchange
    // returns the JWT as the access token instead (mirrors RN's
    // `idToken ?? accessToken`). Either way the kept token is the JWT.
    guard let token = decoded.idToken ?? decoded.accessToken else {
      throw NearError.loginFailed("unreadable token response")
    }
    let claims = try jwtClaims(token)
    guard let subject = claims["sub"] as? String, !subject.isEmpty,
      let expiry = claims["exp"] as? Int
    else {
      throw NearError.loginFailed("id token carries no sub/exp")
    }
    return PasskeySession(
      idToken: token,
      refreshToken: decoded.refreshToken,
      expiresAt: Date(timeIntervalSince1970: TimeInterval(expiry)),
      subject: subject
    )
  }

  private nonisolated func jwtClaims(_ jwt: String) throws -> [String: Any] {
    let segments = jwt.split(separator: ".")
    guard segments.count >= 2 else {
      throw NearError.loginFailed("malformed id token")
    }
    var payload = String(segments[1])
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    while payload.count % 4 != 0 { payload += "=" }
    guard let data = Data(base64Encoded: payload),
      let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      throw NearError.loginFailed("unreadable id token")
    }
    return claims
  }
}
