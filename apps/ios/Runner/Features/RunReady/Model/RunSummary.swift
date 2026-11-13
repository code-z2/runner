import Foundation
import RunnerStore

struct RunSummary: Identifiable, Hashable, Sendable {

  let id: UUID
  let distanceMeters: Double?
  let elapsed: TimeInterval
  let date: Date
  var cadenceStepsPerMinute: Int? = nil
  var encounters: RunEncounters? = nil
}

extension RunSummary {

  init(record: RunRecordSnapshot) {
    self.init(
      id: record.id, distanceMeters: record.distanceMeters,
      elapsed: record.activeElapsed, date: record.startedAt,
      cadenceStepsPerMinute: record.cadenceStepsPerMinute,
      encounters: record.encounters)
  }
}
