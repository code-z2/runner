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

  private var active = false

  private var advertisedWindow: Int?

  private var continuation: AsyncStream<ProximitySighting>.Continuation?

  private var pump: Task<Void, Never>?

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
    active
  }

  public func start() async throws {
    guard !active else {
      throw EncounterError.alreadyActive
    }
    let (stream, continuation) = AsyncStream.makeStream(of: ProximitySighting.self)
    do {
      try await advertiser.start()
      advertisedWindow = rotation.windowIndex(for: clock())
      try await scanner.start { continuation.yield($0) }
    } catch {
      continuation.finish()
      throw error
    }
    active = true
    self.continuation = continuation
    pump = Task.detached { [weak self] in
      guard let self else {
        return
      }
      for await sighting in stream {
        await self.handle(sighting)
      }
    }
  }

  public func stop() async {
    continuation?.finish()
    continuation = nil
    if let pump {
      await pump.value
      self.pump = nil
    }
    active = false
    advertisedWindow = nil
    await scanner.stop()
    await advertiser.stop()
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
