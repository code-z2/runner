import ActivityKit
import Foundation

struct RunActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let elapsed: TimeInterval
    let runningSince: Date?
    let distanceMeters: Double?
    /// Average pace in seconds per kilometer, if distance has been recorded.
    let averagePace: TimeInterval?

    init(
      elapsed: TimeInterval,
      runningSince: Date? = nil,
      distanceMeters: Double? = nil,
      averagePace: TimeInterval? = nil
    ) {
      self.elapsed = elapsed
      self.runningSince = runningSince
      self.distanceMeters = distanceMeters
      self.averagePace = averagePace
    }
  }
}
