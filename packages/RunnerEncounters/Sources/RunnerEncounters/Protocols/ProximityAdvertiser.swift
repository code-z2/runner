//
//  ProximityAdvertiser.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

/// Broadcasts our service UUID with the current rotating ID.
/// `refreshIdentity` re-advertises under the new rotation window.
public protocol ProximityAdvertiser: Sendable {

  func start() async throws

  func stop() async

  func refreshIdentity() async
}
