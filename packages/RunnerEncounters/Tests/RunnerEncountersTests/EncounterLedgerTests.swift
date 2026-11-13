//
//  EncounterLedgerTests.swift
//  RunnerEncountersTests
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import Testing

@testable import RunnerEncounters

struct EncounterLedgerTests {

  private final class TestClock: @unchecked Sendable {

    var now = Date(timeIntervalSince1970: 10_000)

    func advance(by interval: TimeInterval) {
      now = now.addingTimeInterval(interval)
    }
  }

  private func sighting(
    peer: UUID = UUID(),
    rssi: Int = -70,
    at option: Date? = nil,
    clock: TestClock
  ) -> ProximitySighting {
    ProximitySighting(
      peer: EncounterPeer(peripheralID: peer, broadcastID: nil),
      rssi: rssi,
      at: option ?? clock.now
    )
  }

  @Test
  func firstSightingCountsFirst() {
    let clock = TestClock()
    var ledger = EncounterLedger(now: { clock.now })

    let effects = ledger.record(sighting(clock: clock))

    #expect(effects == [.countedFirst])
    #expect(ledger.counts.first == 1)
  }

  @Test
  func repeatSightingWithinWindowCountsNothing() {
    let clock = TestClock()
    var ledger = EncounterLedger(now: { clock.now })
    let peer = UUID()
    _ = ledger.record(sighting(peer: peer, clock: clock))

    clock.advance(by: 10)
    let effects = ledger.record(sighting(peer: peer, clock: clock))

    #expect(effects == [])
    #expect(ledger.counts == EncounterCounts(first: 1, repeat: 0, dwell: 0))
  }

  @Test
  func absenceBeyondGapCountsRepeat() {
    let clock = TestClock()
    var ledger = EncounterLedger(now: { clock.now })
    let peer = UUID()
    _ = ledger.record(sighting(peer: peer, clock: clock))

    clock.advance(by: 360)
    let effects = ledger.record(sighting(peer: peer, clock: clock))

    #expect(effects == [.countedRepeat])
    #expect(ledger.counts.repeat == 1)
  }

  @Test
  func continuousPresenceFiresDwellOnce() {
    let clock = TestClock()
    var ledger = EncounterLedger(now: { clock.now })
    let peer = UUID()
    _ = ledger.record(sighting(peer: peer, clock: clock))

    clock.advance(by: 30)
    #expect(ledger.record(sighting(peer: peer, clock: clock)) == [])

    clock.advance(by: 31)
    #expect(ledger.record(sighting(peer: peer, clock: clock)) == [.dwellReached])

    clock.advance(by: 30)
    #expect(ledger.record(sighting(peer: peer, clock: clock)) == [])
    #expect(ledger.counts.dwell == 1)
  }

  @Test
  func pausedTimeDoesNotCountTowardDwell() {
    let clock = TestClock()
    var ledger = EncounterLedger(now: { clock.now })
    let peer = UUID()
    _ = ledger.record(sighting(peer: peer, clock: clock))
    ledger.endSegment()

    clock.advance(by: 90)
    #expect(ledger.record(sighting(peer: peer, clock: clock)) == [])
    clock.advance(by: 61)
    #expect(ledger.record(sighting(peer: peer, clock: clock)) == [.dwellReached])
  }

  @Test
  func newVisitResetsDwell() {
    let clock = TestClock()
    var ledger = EncounterLedger(now: { clock.now })
    let peer = UUID()
    _ = ledger.record(sighting(peer: peer, clock: clock))
    clock.advance(by: 61)
    _ = ledger.record(sighting(peer: peer, clock: clock))

    clock.advance(by: 400)
    #expect(ledger.record(sighting(peer: peer, clock: clock)) == [.countedRepeat])

    clock.advance(by: 61)
    #expect(ledger.record(sighting(peer: peer, clock: clock)) == [.dwellReached])
    #expect(ledger.counts.dwell == 2)
  }

  @Test
  func prunedPeersCountAsFirstAgain() {
    let clock = TestClock()
    var ledger = EncounterLedger(now: { clock.now })
    let peer = UUID()
    _ = ledger.record(sighting(peer: peer, clock: clock))

    clock.advance(by: 31 * 24 * 3_600)
    let effects = ledger.record(sighting(peer: peer, clock: clock))

    #expect(effects == [.countedFirst])
    #expect(ledger.counts.first == 2)
  }
}
