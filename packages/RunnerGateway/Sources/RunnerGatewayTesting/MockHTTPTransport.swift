//
//  MockHTTPTransport.swift
//  RunnerGatewayTesting
//
//  Created by Peter on 08/11/2026.
//

import Foundation
import RunnerGateway

/// Scripted transport: replays one queued response per request, records
/// everything sent. An empty queue is a transport failure — tests must
/// say what the network says.
public actor MockHTTPTransport: HTTPTransport {

  private var queued: [(Data, Int)] = []
  private var recorded: [URLRequest] = []

  public init() {}

  public func enqueue(_ data: Data, status: Int = 200) {
    queued.append((data, status))
  }

  public var lastRequest: URLRequest? {
    recorded.last
  }

  public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    recorded.append(request)
    guard !queued.isEmpty else {
      throw GatewayError.transport("no response queued")
    }
    let (data, status) = queued.removeFirst()
    guard let url = request.url,
      let response = HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: nil,
        headerFields: nil
      )
    else {
      throw GatewayError.invalidResponse
    }
    return (data, response)
  }
}
