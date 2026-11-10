//
//  GatewayClient.swift
//  RunnerGateway
//
//  Created by Peter on 08/11/2026.
//

/// Typed boundary to `apps/api`. Device-key material (App Attest) and
/// account signatures (NEAR) are produced by the platform and wallet
/// layers and arrive as strings — this client never generates keys.
public protocol GatewayClient: Sendable {

  func challenge() async throws -> Challenge

  @discardableResult
  func registerDevice(_ registration: DeviceRegistration) async throws -> String

  func claimPass(_ request: ClaimPassRequest) async throws -> ClaimPass

  /// Seed the runner's implicit account. Idempotent: an existing account
  /// returns `seeded: false`. A dry funder surfaces as `GatewayError.server`.
  func seed(_ request: SeedRequest) async throws -> SeedResult

  func merchants(cells: [String]) async throws -> [MerchantLocation]
}
