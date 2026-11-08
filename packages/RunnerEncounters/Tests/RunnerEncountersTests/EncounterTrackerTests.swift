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
  func doubleStartThrowsAlreadyActive() async throws {
    let box = NowBox()
    let tracker = tracker(scanner: MockProximityScanner(sightings: []), box: box)

    try await tracker.start()

    await #expect(throws: EncounterError.alreadyActive) {
      try await tracker.start()
    }
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
