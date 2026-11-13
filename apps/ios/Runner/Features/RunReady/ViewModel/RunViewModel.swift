import Foundation
import Observation

@MainActor
@Observable
final class RunViewModel: AppViewModelType {

  private(set) var runs: [RunSummary]
  private(set) var historyUnavailable = false

  @ObservationIgnored
  private var loadGeneration = 0

  private let loadRuns: (@MainActor () async throws -> [RunSummary])?

  init(runs: [RunSummary] = [], loadRuns: (@MainActor () async throws -> [RunSummary])? = nil) {
    self.runs = runs
    self.loadRuns = loadRuns
  }

  func refreshHistory() async {
    guard let loadRuns else { return }
    loadGeneration += 1
    let generation = loadGeneration
    do {
      let records = try await loadRuns()
      guard generation == loadGeneration, !Task.isCancelled else { return }
      runs = records
      historyUnavailable = false
    } catch {
      guard generation == loadGeneration, !Task.isCancelled else { return }
      historyUnavailable = true
    }
  }
}
