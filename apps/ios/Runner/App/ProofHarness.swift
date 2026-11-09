//
//  ProofHarness.swift
//  Runner
//
//  DEBUG ONLY. Interactive NEAR Auth ceremony proof: passkey login,
//  fatxn-bound JWT, MPC account resolution on testnet. Never ships:
//  compiled into Debug builds only, never referenced by Release code.
//

#if DEBUG
import AuthenticationServices
import CryptoKit
import Foundation
import RunnerNear
import SwiftUI

/// URLSession-backed auth transport for the proof only.
private struct ProofTransport: AuthTransport, Sendable {

  func send(_ request: URLRequest) async throws -> (Data, Int) {
    let (data, response) = try await URLSession.shared.data(for: request)
    return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
  }
}

@MainActor
private final class ProofModel: ObservableObject {

  @Published var lines: [String] = ["Ready. Tap Run to start the ceremony."]
  @Published var running = false

  private let anchor = SheetAnchor()
  private var webSession: ASWebAuthenticationSession?

  func log(_ line: String) {
    lines.append(line)
    NSLog("PROOF %@", line)
  }

  func run() {
    guard !running else { return }
    running = true
    lines = []
    Task {
      await ceremony()
      running = false
    }
  }

  private final class SheetAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {

    fileprivate func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.keyWindow ?? ASPresentationAnchor()
    }
  }

  private func ceremony() async {
    do {
      let network = NearNetwork.testnet(relayerURL: URL(string: "https://relayer.test")!)
      let core = LiveNearCore()
      let rpc = try LiveNearRpc(rpcURL: network.rpcURL.absoluteString)
      let provider = Auth0PasskeyProvider(network: network, transport: ProofTransport())
      let verifier = random(32)
      let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded()
      let message = "runner proof"
      let nonce = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
      let digest = try core.nep413DigestHex(
        message: message,
        nonceBase64: nonce.base64EncodedString(),
        recipient: "runner-api"
      )
      log("digest \(digest.prefix(16))…")
      let payload = Data(hex: digest) ?? Data()
      let url = try provider.authorizeSignatureURL(
        payload: .nep413(payload),
        redirectURI: "runner://auth",
        state: "proof1",
        codeChallenge: challenge
      )
      log("sheet opening…")
      let callback: URL = try await withCheckedThrowingContinuation { cont in
        let session = ASWebAuthenticationSession(
          url: url,
          callbackURLScheme: "runner"
        ) { url, error in
          if let url {
            cont.resume(returning: url)
          } else {
            cont.resume(throwing: error ?? NearError.loginFailed("sheet dismissed"))
          }
        }
        session.presentationContextProvider = anchor
        session.prefersEphemeralWebBrowserSession = true
        webSession = session
        session.start()
      }
      log("callback received")
      let jwt = try await provider.completeSignatureCallback(
        callback,
        codeVerifier: verifier,
        redirectURI: "runner://auth",
        expectedPayloadHex: digest
      )
      log("fatxn verified, jwt \(jwt.prefix(24))…")
      let subject = jwtSubject(jwt) ?? "?"
      let session = PasskeySession(
        idToken: jwt,
        refreshToken: nil,
        expiresAt: Date().addingTimeInterval(3600),
        subject: subject
      )
      let account = try await MpcAccountResolver(network: network, rpc: rpc, core: core)
        .resolve(session: session)
      log("account \(account.accountID)")
      log("key \(account.publicKey.prefix(24))…")
      do {
        let key = try await rpc.accessKey(accountID: account.accountID, publicKey: account.publicKey)
        log("access key found nonce=\(key.nonce) fullAccess=\(key.fullAccess)")
      } catch {
        log("account unfunded (expected pre-faucet): \(error)")
      }
      log("PROOF COMPLETE")
    } catch {
      webSession = nil
      log("FAILED: \(error)")
    }
  }

  private func random(_ count: Int) -> String {
    Data((0..<count).map { _ in UInt8.random(in: 0...255) }).base64URLEncoded()
  }

  private func jwtSubject(_ jwt: String) -> String? {
    let parts = jwt.split(separator: ".")
    guard parts.count >= 2 else { return nil }
    var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    while b64.count % 4 != 0 { b64 += "=" }
    guard let data = Data(base64Encoded: b64),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return json["sub"] as? String
  }
}

private extension Data {

  func base64URLEncoded() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  init?(hex: String) {
    var data = Data()
    var index = hex.startIndex
    while index < hex.endIndex {
      let next = hex.index(index, offsetBy: 2)
      guard next <= hex.endIndex, let byte = UInt8(hex[index..<next], radix: 16) else {
        return nil
      }
      data.append(byte)
      index = next
    }
    self = data
  }
}

struct ProofHarnessView: View {

  @StateObject private var model = ProofModel()

  var body: some View {
    NavigationStack {
      VStack {
        List(model.lines.indices, id: \.self) { i in
          Text(model.lines[i]).font(.caption).textSelection(.enabled)
        }
        Button(model.running ? "Running…" : "Run ceremony proof") {
          model.run()
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.running)
        .padding()
      }
      .navigationTitle("NEAR Proof")
    }
  }
}
#endif
