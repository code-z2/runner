//
//  EncounterPeer.swift
//  RunnerEncounters
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// One nearby app instance. The OS-provided identifier is the stable dedup
/// key; the broadcast ID is an opportunistic foreground extra. Two sightings
/// with the same peripheral identifier are the same peer, whatever the
/// broadcast ID says — rotation can never inflate counts.
public struct EncounterPeer: Sendable, Equatable, Hashable {

  public let peripheralID: UUID

  public let broadcastID: String?

  public init(peripheralID: UUID, broadcastID: String?) {
    self.peripheralID = peripheralID
    self.broadcastID = broadcastID
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(peripheralID)
  }

  public static func == (lhs: EncounterPeer, rhs: EncounterPeer) -> Bool {
    lhs.peripheralID == rhs.peripheralID
  }
}
