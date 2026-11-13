//
//  EncounterTracker.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// Owns one encounter session: advertises our rotating ID, counts sightings,
/// and requests graded buzzes. The ledger and grader hold the policy;
/// this actor holds the lifecycle.
///
/// Sightings flow through one session-scoped pump task so they process in
/// order and `stop` drains everything already seen. The pump is detached on
/// purpose: it must not occupy the actor, and its lifetime is exactly
/// `start` to `stop`.
public actor EncounterTracker {

  private let scanner: any ProximityScanner

  private let advertiser: any ProximityAdvertiser

  private let haptics: any EncounterHaptics

  private let rotation: RotatingIdentifier

  private let clock: @Sendable () -> Date

  private var ledger: EncounterLedger

  private var grader = RssiGrader()

  private enum Phase {
    case idle
    case starting
    case active
    case stopping
  }

  private var phase = Phase.idle
  private var transition: Task<Void, any Error>?

  private var advertisedWindow: Int?

  private var continuation: AsyncStream<ProximitySighting>.Continuation?

  private var pump: Task<Void, Never>?

  /// Synchronous actor initializers run before the actor's identity is
  /// established, so composition roots can call this from stored
  /// properties. Safe: the body only assigns stored properties.
  public init(
    scanner: some ProximityScanner,
    advertiser: some ProximityAdvertiser,
    haptics: some EncounterHaptics,
    rotation: RotatingIdentifier,
    clock: @Sendable @escaping () -> Date = Date.init
  ) {
    self.scanner = scanner
    self.advertiser = advertiser
    self.haptics = haptics
    self.rotation = rotation
    self.clock = clock
    self.ledger = EncounterLedger(now: clock)
  }

  public var counts: EncounterCounts {
    ledger.counts
  }

  public var isActive: Bool {
    phase == .active
  }

  public func start() async throws {
    guard phase == .idle else {
      throw EncounterError.alreadyActive
    }
    phase = .starting
    let startup = Task { try await startTracking() }
    transition = startup
    try await startup.value
  }

  private func startTracking() async throws {
    defer { transition = nil }
    let (stream, continuation) = AsyncStream.makeStream(of: ProximitySighting.self)
    do {
      try await advertiser.start()
      advertisedWindow = rotation.windowIndex(for: clock())
      try await scanner.start { continuation.yield($0) }
    } catch {
      continuation.finish()
      advertisedWindow = nil
      await scanner.stop()
      await advertiser.stop()
      phase = .idle
      throw error
    }
    phase = .active
    self.continuation = continuation
    pump = Task.detached { [weak self] in
      for await sighting in stream {
        guard let self else { return }
        await self.handle(sighting)
      }
    }
  }

  public func stop() async {
    if phase == .starting {
      _ = try? await transition?.value
    }
    if phase == .stopping {
      _ = try? await transition?.value
      return
    }
    guard phase == .active else { return }
    phase = .stopping
    let shutdown = Task<Void, any Error> { await stopTracking() }
    transition = shutdown
    _ = try? await shutdown.value
  }

  private func stopTracking() async {
    continuation?.finish()
    continuation = nil
    if let pump {
      await pump.value
      self.pump = nil
    }
    ledger.endSegment()
    advertisedWindow = nil
    await scanner.stop()
    await advertiser.stop()
    phase = .idle
    transition = nil
  }

  private func handle(_ sighting: ProximitySighting) async {
    let window = rotation.windowIndex(for: sighting.at)
    if advertisedWindow != window {
      advertisedWindow = window
      await advertiser.refreshIdentity()
    }
    let effects = ledger.record(sighting)
    guard !effects.isEmpty else {
      return
    }
    if let intensity = grader.grade(
      peer: sighting.peer.peripheralID, rssi: sighting.rssi, at: sighting.at)
    {
      haptics.buzz(intensity)
    }
  }
}
