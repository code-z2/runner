//
//  ProximitySighting.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// One observed advertisement. Raw sightings stay on device; only counters
/// and haptic requests leave this package.
public struct ProximitySighting: Sendable, Equatable {

  public let peer: EncounterPeer

  public let rssi: Int

  public let at: Date

  public init(peer: EncounterPeer, rssi: Int, at: Date) {
    self.peer = peer
    self.rssi = rssi
    self.at = at
  }
}
