//
//  URLSessionAuthTransport.swift
//  Runner
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerNear

/// Live `AuthTransport` over `URLSession`. The only networking the auth
/// sheet needs; timeouts stay tight so a stalled tenant fails fast.
struct URLSessionAuthTransport: AuthTransport, Sendable {

  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func send(_ request: URLRequest) async throws -> (Data, Int) {
    let (data, response) = try await session.data(for: request)
    return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
  }
}
