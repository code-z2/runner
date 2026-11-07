//
//  CadenceUpdateSource.swift
//  RunnerCadence
//
//  Created by Peter on 07/11/2026.
//

/// Pushes `CadenceEvent` values into a handler until stopped.
/// Handlers cross isolation domains, so they are `@Sendable`.
public protocol CadenceUpdateSource: Sendable {

  func start(handler: @Sendable @escaping (CadenceEvent) -> Void) async throws

  func stop() async
}
