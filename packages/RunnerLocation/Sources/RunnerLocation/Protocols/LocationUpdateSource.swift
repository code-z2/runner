//
//  LocationUpdateSource.swift
//  RunnerLocation
//
//  Created by Peter on 07/11/2026.
//

/// Pushes `LocationEvent` values into a handler until stopped.
/// Handlers cross isolation domains, so they are `@Sendable`.
public protocol LocationUpdateSource: Sendable {

    func start(handler: @Sendable @escaping (LocationEvent) -> Void) async

    func stop() async
}
