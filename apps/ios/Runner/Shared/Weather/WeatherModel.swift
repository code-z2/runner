import Foundation
import Observation

/// Freshness-owned run weather. Fetches on demand through the injected
/// service and enforces a staleness policy: at most one request every
/// `staleness` interval, at most one in flight, and a failed fetch never
/// erases the last good value. Call `refresh()` when the app foregrounds
/// or the Run tab needs current conditions.
@MainActor
@Observable
final class WeatherModel: AppViewModelType {

  static let staleness: TimeInterval = 15 * 60

  private(set) var weather: RunWeather?

  private(set) var fetchedAt: Date?

  private var refreshing = false

  private let fetch: @Sendable () async -> RunWeather?

  private let now: @Sendable () -> Date

  init(
    weather: RunWeather? = nil,
    fetchedAt: Date? = nil,
    fetch: @escaping @Sendable () async -> RunWeather?,
    now: @escaping @Sendable () -> Date = { .now }
  ) {
    self.weather = weather
    self.fetchedAt = fetchedAt
    self.fetch = fetch
    self.now = now
  }

  var isStale: Bool {
    guard let fetchedAt else { return true }
    return now() >= fetchedAt.addingTimeInterval(Self.staleness)
  }

  func refresh() async {
    guard !refreshing, weather == nil || isStale else { return }
    refreshing = true
    defer { refreshing = false }
    guard !Task.isCancelled else { return }
    guard let fresh = await fetch(), !Task.isCancelled else { return }
    weather = fresh
    fetchedAt = now()
  }
}
