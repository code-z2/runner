//
//  RunnerGatewayClient.swift
//  RunnerGateway
//
//  Created by Peter on 08/11/2026.
//

import Foundation

/// Live `GatewayClient` over an `HTTPTransport`. Owns URL construction
/// and codec work; the transport moves bytes, the server owns policy.
public struct RunnerGatewayClient: GatewayClient, Sendable {

  private let baseURL: URL
  private let transport: any HTTPTransport

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    return decoder
  }()

  public init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport()) throws {
    guard ["http", "https"].contains(baseURL.scheme?.lowercased()) else {
      throw GatewayError.invalidBaseURL
    }
    self.baseURL = baseURL
    self.transport = transport
  }

  public func challenge() async throws -> Challenge {
    let request = try post(path: "v1/challenge", body: EmptyBody())
    return try await send(request, as: Challenge.self, success: 201)
  }

  @discardableResult
  public func registerDevice(_ registration: DeviceRegistration) async throws -> String {
    struct Response: Decodable {
      let keyID: String
      private enum CodingKeys: String, CodingKey {
        case keyID = "key_id"
      }
    }
    let request = try post(path: "v1/devices", body: registration)
    return try await send(request, as: Response.self, success: 201).keyID
  }

  public func claimPass(_ request: ClaimPassRequest) async throws -> ClaimPass {
    let urlRequest = try post(path: "v1/attestations", body: request)
    return try await send(urlRequest, as: ClaimPass.self, success: 201)
  }

  public func seed(_ request: SeedRequest) async throws -> SeedResult {
    let urlRequest = try post(path: "v1/seed", body: request)
    return try await send(urlRequest, as: SeedResult.self, success: 200)
  }

  public func merchants(cells: [String]) async throws -> [MerchantLocation] {
    guard !cells.isEmpty else {
      throw GatewayError.invalidRequest("cells must not be empty")
    }
    var components = URLComponents(
      url: baseURL.appending(path: "v1/merchants"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [URLQueryItem(name: "cells", value: cells.joined(separator: ","))]
    guard let url = components?.url else {
      throw GatewayError.invalidRequest("unbuildable merchants URL")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    return try await send(request, as: MerchantList.self, success: 200).locations
  }

  // MARK: - Plumbing

  private func post<Body: Encodable>(path: String, body: Body) throws -> URLRequest {
    var request = URLRequest(url: baseURL.appending(path: path))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    do {
      request.httpBody = try JSONEncoder().encode(body)
    } catch {
      throw GatewayError.invalidRequest("unencodable body for \(path)")
    }
    return request
  }

  private func send<T: Decodable>(
    _ request: URLRequest,
    as type: T.Type,
    success: Int
  ) async throws -> T {
    let (data, response): (Data, HTTPURLResponse)
    do {
      (data, response) = try await transport.send(request)
    } catch let error as GatewayError {
      throw error
    } catch {
      throw GatewayError.transport(String(describing: error))
    }
    guard response.statusCode == success else {
      throw GatewayError.server(status: response.statusCode, code: serverCode(from: data))
    }
    do {
      return try Self.decoder.decode(T.self, from: data)
    } catch {
      throw GatewayError.decoding(String(describing: error))
    }
  }

  private func serverCode(from data: Data) -> String {
    struct Envelope: Decodable {
      let error: String?
    }
    return (try? Self.decoder.decode(Envelope.self, from: data))?.error ?? "unknown"
  }

  private struct EmptyBody: Encodable {}
}
