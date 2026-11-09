//
//  MockAuthTransport.swift
//  RunnerNearTesting
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// Scripted auth HTTP: one queued response per request, records all bodies.
public actor MockAuthTransport: AuthTransport {

  private var queued: [(Data, Int)] = []
  public private(set) var requests: [URLRequest] = []

  public init() {}

  public func enqueue(json: String, status: Int = 200) {
    queued.append((Data(json.utf8), status))
  }

  public func formBody(of request: URLRequest) -> [String: String] {
    guard let data = request.httpBody, let text = String(data: data, encoding: .utf8) else {
      return [:]
    }
    var fields: [String: String] = [:]
    for pair in text.split(separator: "&") {
      let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
      if parts.count == 2 {
        fields[parts[0].removingPercentEncoding ?? parts[0]] =
          parts[1].removingPercentEncoding ?? parts[1]
      }
    }
    return fields
  }

  public func send(_ request: URLRequest) async throws -> (Data, Int) {
    requests.append(request)
    guard !queued.isEmpty else {
      throw NearError.transport("no response queued")
    }
    return queued.removeFirst()
  }
}
