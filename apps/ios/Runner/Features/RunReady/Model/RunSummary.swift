import Foundation

struct RunSummary: Identifiable, Hashable, Sendable {

  let id: UUID
  let distanceMeters: Double?
  let elapsed: TimeInterval
  let date: Date
}
