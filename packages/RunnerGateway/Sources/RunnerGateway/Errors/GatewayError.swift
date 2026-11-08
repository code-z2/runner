//
//  GatewayError.swift
//  RunnerGateway
//
//  Created by Peter on 08/11/2026.
//

/// Every failure mode of the gateway, typed once. Server failures carry
/// the status and the machine-readable `error` code from the envelope
/// (`too_soon`, `misconfigured`, …) so callers branch on values, not text.
public enum GatewayError: Sendable, Equatable, Error {

  case invalidBaseURL
  case invalidRequest(String)
  case transport(String)
  case invalidResponse
  case decoding(String)
  case server(status: Int, code: String)
}
