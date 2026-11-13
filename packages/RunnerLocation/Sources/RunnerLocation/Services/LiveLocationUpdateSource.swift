//
//  LiveLocationUpdateSource.swift
//  RunnerLocation
//
//  Created by Peter on 07/11/2026.
//

import CoreLocation

/// Live system updates with fitness tuning. Holds its service session for
/// exactly the run of its pump task, so background delivery keeps flowing.
///
/// All mutation happens on the tracker's call path: `start` then `stop`,
/// never concurrently. No shared state is touched from two threads, which is
/// why `@unchecked Sendable` is sound here rather than a lock.
@available(
  macOS, unavailable, message: "Live updates need a service session, which macOS does not offer."
)
public final class LiveLocationUpdateSource: LocationUpdateSource, @unchecked Sendable {

  private var session: CLServiceSession?

  private var backgroundActivity: CLBackgroundActivitySession?

  private var pump: Task<Void, Never>?

  public init() {}

  public func start(handler: @Sendable @escaping (LocationEvent) -> Void) async {
    guard pump == nil else {
      return
    }
    backgroundActivity = CLBackgroundActivitySession()
    session = CLServiceSession(authorization: .whenInUse)
    pump = Task {
      do {
        for try await update in CLLocationUpdate.liveUpdates(
          CLLocationUpdate.LiveConfiguration.fitness
        ) {
          try Task.checkCancellation()
          let events = LocationEventMapper.events(
            location: update.location,
            flags: LocationUpdateFlags(update: update)
          )
          for event in events {
            handler(event)
          }
        }
      } catch {
        return
      }
    }
  }

  public func stop() async {
    pump?.cancel()
    pump = nil
    session = nil
    backgroundActivity?.invalidate()
    backgroundActivity = nil
  }
}
