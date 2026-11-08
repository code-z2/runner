//
//  ProximityScanner.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

/// Pushes sightings of our service UUID until stopped.
/// Handlers cross isolation domains, so they are `@Sendable`.
public protocol ProximityScanner: Sendable {

  func start(handler: @Sendable @escaping (ProximitySighting) -> Void) async throws

  func stop() async
}
