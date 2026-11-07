//
//  CadenceEventMapper.swift
//  RunnerCadence
//
//  Created by Peter on 07/11/2026.
//

import Foundation

/// Pure mapping from a pedometer delivery to downstream events.
/// A handler error means the sensor is gone. A missing cadence is just
/// an unknown sample, not a failure.
enum CadenceEventMapper {

  static func events(
    currentCadence: NSNumber?,
    error: Error?,
    timestamp: Date
  ) -> [CadenceEvent] {
    if error != nil {
      return [.unavailable]
    }
    return [.sample(CadenceSampleModel(currentCadence: currentCadence, timestamp: timestamp))]
  }
}
