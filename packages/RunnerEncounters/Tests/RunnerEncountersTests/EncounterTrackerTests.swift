//
//  EncounterTrackerTests.swift
//  RunnerEncountersTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerEncountersTesting
import Testing

@testable import RunnerEncounters

struct EncounterTrackerTests {

  private final class NowBox: @unchecked Sendable {

    var now = Date(timeIntervalSince1970: 10_000)
  }

  private func sighting(peer: UUID, rssi: Int, at: Date) -> ProximitySighting {
    ProximitySighting(peer: EncounterPeer(peripheralID: peer, broadcastID: nil), rssi: rssi, at: at)
  }

  private func tracker(
    scanner: MockProximityScanner,
    advertiser: MockProximityAdvertiser = MockProximityAdvertiser(),
    haptics: MockEncounterHaptics = MockEncounterHaptics(),
    box: NowBox
  ) -> EncounterTracker {
    EncounterTracker(
      scanner: scanner,
      advertiser: advertiser,
      haptics: haptics,
      rotation: RotatingIdentifier(root: UUID(), windowLength: 900),
      clock: { box.now }
    )
  }

  @Test
  func startFlowsSightingsIntoCounts() async throws {
    let box = NowBox()
    let scanner = MockProximityScanner(sightings: [
      sighting(peer: UUID(), rssi: -55, at: box.now),
      sighting(peer: UUID(), rssi: -85, at: box.now.addingTimeInterval(1)),
    ])
    let tracker = tracker(scanner: scanner, box: box)

    try await tracker.start()
    try await tracker.stop()

    #expect(await tracker.counts.first == 2)
    #expect(scanner.startedCount == 1)
  }

  @Test
  func firstSightingRequestsBuzz() async throws {
    let box = NowBox()
    let scanner = MockProximityScanner(sightings: [
      sighting(peer: UUID(), rssi: -55, at: box.now)
    ])
    let haptics = MockEncounterHaptics()
    let tracker = tracker(scanner: scanner, haptics: haptics, box: box)

    try await tracker.start()
    try await tracker.stop()

    #expect(haptics.buzzed == [.heavy])
  }

  @Test
  func scannerStartFailureStopsAdvertising() async {
    let advertiser = MockProximityAdvertiser()
    let tracker = EncounterTracker(
      scanner: FailingScanner(), advertiser: advertiser, haptics: MockEncounterHaptics(),
      rotation: RotatingIdentifier(root: UUID()))

    await #expect(throws: CocoaError.self) { try await tracker.start() }
    #expect(advertiser.startedCount == 1)
    #expect(advertiser.stoppedCount == 1)
    #expect(await !tracker.isActive)
  }

  private struct FailingScanner: ProximityScanner {
    func start(handler: @Sendable @escaping (ProximitySighting) -> Void) async throws {
      throw CocoaError(.featureUnsupported)
    }

    func stop() async {}
  }

  @Test
  func stopWhileScannerStartsLeavesTrackingStopped() async throws {
    let scanner = SuspendedScanner()
    let advertiser = MockProximityAdvertiser()
    let tracker = EncounterTracker(
      scanner: scanner, advertiser: advertiser, haptics: MockEncounterHaptics(),
      rotation: RotatingIdentifier(root: UUID()))

    let start = Task { try await tracker.start() }
    await scanner.waitForStart()
    await #expect(throws: EncounterError.alreadyActive) { try await tracker.start() }
    let stop = Task { await tracker.stop() }
    await scanner.completeStart()
    try await start.value
    await stop.value

    #expect(await !tracker.isActive)
    #expect(await scanner.stops == 1)
    #expect(advertiser.stoppedCount == 1)
  }

  private actor SuspendedScanner: ProximityScanner {
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    private(set) var stops = 0

    func start(handler: @Sendable @escaping (ProximitySighting) -> Void) async throws {
      await withCheckedContinuation {
        startContinuation = $0
        observer?.resume()
        observer = nil
      }
    }

    func waitForStart() async {
      guard startContinuation == nil else { return }
      await withCheckedContinuation { observer = $0 }
    }

    func completeStart() {
      startContinuation?.resume()
      startContinuation = nil
    }

    func stop() async { stops += 1 }
  }

  @Test
  func doubleStartThrowsAlreadyActive() async throws {
    let box = NowBox()
    let tracker = tracker(scanner: MockProximityScanner(sightings: []), box: box)

    try await tracker.start()

    await #expect(throws: EncounterError.alreadyActive) {
      try await tracker.start()
    }
    await tracker.stop()
  }

  @Test
  func rotationWindowChangeRefreshesAdvertisedIdentity() async throws {
    let box = NowBox()
    let scanner = MockProximityScanner(sightings: [
      sighting(peer: UUID(), rssi: -70, at: box.now),
      sighting(peer: UUID(), rssi: -70, at: box.now.addingTimeInterval(901)),
    ])
    let advertiser = MockProximityAdvertiser()
    let tracker = tracker(scanner: scanner, advertiser: advertiser, box: box)

    try await tracker.start()
    try await tracker.stop()

    #expect(advertiser.refreshedCount == 1)
  }
}
