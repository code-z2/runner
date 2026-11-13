public struct RunEncounterCounts: Hashable, Sendable {
  public let new: Int
  public let again: Int
  public let together: Int

  public init(new: Int, again: Int, together: Int) {
    self.new = new
    self.again = again
    self.together = together
  }
}
