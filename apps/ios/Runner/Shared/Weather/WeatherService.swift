import CoreLocation
import Foundation
import WeatherKit
import os

struct RunWeatherService: Sendable {

  private static let weatherLog = Logger(subsystem: "io.wades.ije", category: "startup-weather")

  func currentWeather() async -> RunWeather? {
    guard let location = await resolveLocation(), !Task.isCancelled else { return nil }
    do {
      let current = try await WeatherKit.WeatherService.shared.weather(
        for: location, including: .current)
      return .init(
        temperature: current.temperature, condition: current.condition.description,
        symbolName: current.symbolName)
    } catch {
      Self.logFailure(error, stage: "Weather")
      return nil
    }
  }

  private func resolveLocation() async -> CLLocation? {
    await withTaskGroup(of: CLLocation?.self) { group in
      group.addTask {
        do {
          for try await update in CLLocationUpdate.liveUpdates() {
            guard !Task.isCancelled else { return nil }
            if update.authorizationDenied || update.authorizationDeniedGlobally { return nil }
            if let location = update.location { return location }
          }
        } catch {
          Self.logFailure(error, stage: "Location")
        }
        return nil
      }
      group.addTask {
        try? await Task.sleep(for: .seconds(5))
        return nil
      }
      let location = await group.next() ?? nil
      group.cancelAll()
      return location
    }
  }

  private static func logFailure(_ error: any Error, stage: String) {
    guard !Task.isCancelled else { return }
    let failure = error as NSError
    weatherLog.error(
      "\(stage, privacy: .public) request failed: \(failure.domain, privacy: .public) (\(failure.code))"
    )
  }
}
