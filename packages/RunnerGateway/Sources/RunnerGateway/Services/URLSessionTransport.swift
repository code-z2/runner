//
//  URLSessionTransport.swift
//  RunnerGateway
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// Live transport over `URLSession`. Non-HTTP responses are rejected —
/// the gateway only ever talks to the worker over HTTP(S).
public struct URLSessionTransport: HTTPTransport, Sendable {

  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw GatewayError.invalidResponse
    }
    return (data, http)
  }
}
