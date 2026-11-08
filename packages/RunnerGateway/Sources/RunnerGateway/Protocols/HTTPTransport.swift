//
//  HTTPTransport.swift
//  RunnerGateway
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// The single seam to the network. The client owns URL and codec logic;
/// transports only move bytes. Tests swap in `MockHTTPTransport`.
public protocol HTTPTransport: Sendable {

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
