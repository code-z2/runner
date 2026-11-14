import CryptoKit
import Foundation
import RunnerNearCore

/// App Attest proof for one proxied request.
public struct DeviceAssertion: Sendable, Equatable {
  public let keyID: String
  public let assertion: String

  public init(keyID: String, assertion: String) {
    self.keyID = keyID
    self.assertion = assertion
  }
}

/// 1Click over the Worker proxy (`/v1/intents/*`). The SDK codecs build the
/// body and decode the reply; the Worker adds the partner key and returns
/// the upstream status and body unchanged.
public struct ProxiedIntentClient: IntentFunctions, Sendable {
  private let baseURL: URL
  private let send: @Sendable (URLRequest) async throws -> (Data, URLResponse)
  private let assert: @Sendable (_ clientData: String) async throws -> DeviceAssertion

  /// `assert` signs `clientData` with the device's App Attest key.
  public init(
    baseURL: URL, session: URLSession = .shared,
    assert: @escaping @Sendable (_ clientData: String) async throws -> DeviceAssertion
  ) {
    self.init(
      baseURL: baseURL,
      send: { try await session.data(for: $0, delegate: RejectRedirects()) },
      assert: assert)
  }

  init(
    baseURL: URL, send: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse),
    assert: @escaping @Sendable (_ clientData: String) async throws -> DeviceAssertion
  ) {
    self.baseURL = baseURL
    self.send = send
    self.assert = assert
  }

  /// The string the device asserts and the Worker re-derives:
  /// `METHOD /v1/intents/<path> <sha256(body) hex>`.
  public static func clientData(method: String, path: String, body: Data) -> String {
    let digest = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
    return "\(method) /v1/intents\(path) \(digest)"
  }

  public func quote(_ request: IntentQuoteRequest) async throws -> IntentQuote {
    let body = try core { try encodeIntentQuote(req: request.core) }
    let data = try await post(path: "/v0/quote", body: body)
    return try core { IntentQuote(core: try decodeIntentQuote(body: data)) }
  }

  private func post(path: String, body: Data) async throws -> Data {
    guard baseURL.scheme == "https" else {
      throw NearError.invalidInput("The 1Click proxy requires an HTTPS base URL.")
    }
    let proof = try await assert(Self.clientData(method: "POST", path: path, body: body))
    var request = URLRequest(
      url: baseURL.appending(path: "v1/intents").appending(path: String(path.dropFirst())),
      timeoutInterval: 30)
    request.httpMethod = "POST"
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(proof.keyID, forHTTPHeaderField: "x-runner-key-id")
    request.setValue(proof.assertion, forHTTPHeaderField: "x-runner-assertion")

    let (data, response) = try await send(request)
    guard let http = response as? HTTPURLResponse else {
      throw NearError.transport("Invalid 1Click proxy response.")
    }
    guard (200..<300).contains(http.statusCode) else {
      let reply = try? JSONDecoder().decode(ErrorReply.self, from: data)
      throw NearError.relayer(
        status: http.statusCode, code: reply?.error ?? reply?.message ?? "intent_proxy_failed")
    }
    return data
  }

  private func core<T>(_ operation: () throws -> T) throws -> T {
    do { return try operation() } catch let error as RunnerNearCore.CoreError {
      throw LiveNearCore.mapCore(error)
    }
  }

  /// Worker errors carry `error`; upstream 1Click errors carry `message`.
  private struct ErrorReply: Decodable {
    let error: String?
    let message: String?
  }
}

extension IntentQuoteRequest {
  fileprivate var core: RunnerNearCore.IntentQuoteRequest {
    .init(
      dry: dry, swapType: swapType, slippageBps: slippageBps, originAsset: originAsset,
      depositType: depositType, destinationAsset: destinationAsset, amount: amount,
      refundTo: refundTo, refundType: refundType, recipient: recipient,
      recipientType: recipientType, deadline: deadline, customRecipientMsg: customRecipientMsg)
  }
}

extension IntentQuote {
  fileprivate init(core: RunnerNearCore.IntentQuote) {
    self.init(
      depositAddress: core.depositAddress, depositMemo: core.depositMemo,
      amountIn: core.amountIn, amountOut: core.amountOut, minAmountOut: core.minAmountOut,
      deadline: core.deadline, timeEstimateSecs: core.timeEstimateSecs)
  }
}

/// Assertion headers must never follow a redirect to another origin.
private final class RejectRedirects: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest
  ) async -> URLRequest? { nil }
}
