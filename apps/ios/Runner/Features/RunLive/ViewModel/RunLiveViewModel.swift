import ActivityKit
import CoreLocation
import Foundation
import OSLog
import Observation
import RunnerCadence
import RunnerHealthKit
import RunnerLocation
import RunnerSession
import RunnerStore

@MainActor
@Observable
final class RunLiveViewModel: AppViewModelType {

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Runner", category: "Workout")

  private(set) var state: SessionState = .idle
  private(set) var elapsed: TimeInterval = 0
  private(set) var isUpdating = false
  private(set) var distanceMeters: Double?
  private(set) var pace: TimeInterval?
  private(set) var cadenceStepsPerMinute: Double?
  private(set) var heartRate: Double?

  var averagePace: TimeInterval? {
    guard let distanceMeters, distanceMeters > 0, elapsed > 0 else { return nil }
    return elapsed * 1_000 / distanceMeters
  }

  private let snapshots: any SessionSnapshotStore
  private let store: @MainActor () throws -> RunStore
  private let location: LocationTracker
  private let cadence: CadenceTracker
  private let healthKit: any HealthKitGateway
  private let canTrackLocation: @MainActor () -> Bool
  private var session: WorkoutSession?
  private static let healthExportKey = "run.appleHealthExport"
  private let preferences: UserDefaults
  private(set) var healthExportEnabled: Bool
  private(set) var healthExportFailed = false
  private(set) var healthWorkoutAccess: Bool

  var isHealthConnected: Bool { healthExportEnabled && healthWorkoutAccess }
  private var activityID: String?
  private var checkpointTask: Task<Void, Never>?
  private var locationTask: Task<Void, Never>?
  private var cadenceTask: Task<Void, Never>?
  private var heartRateTask: Task<Void, Never>?
  private var lastMeasuredCadence: Int?
  private var previousLocation: LocationSampleModel?
  private var segmentStartedAt: Date?

  init(
    snapshots: any SessionSnapshotStore,
    store: @escaping @MainActor () throws -> RunStore,
    location: LocationTracker,
    cadence: CadenceTracker,
    healthKit: any HealthKitGateway,
    preferences: UserDefaults = .standard,
    canTrackLocation: @escaping @MainActor () -> Bool
  ) {
    self.snapshots = snapshots
    self.store = store
    self.location = location
    self.cadence = cadence
    self.healthKit = healthKit
    healthWorkoutAccess = healthKit.canSaveWorkouts
    self.preferences = preferences
    healthExportEnabled = preferences.bool(forKey: Self.healthExportKey)
    self.canTrackLocation = canTrackLocation
  }

  var hasSession: Bool { session != nil || isUpdating }

  func recover() async throws {
    guard !isUpdating, session == nil else { return }
    isUpdating = true
    defer { isUpdating = false }
    try await savePendingRun()
    await endOrphanedActivities()
  }

  func start() async throws {
    if session != nil { return }
    guard !isUpdating else { throw SessionError.alreadyActive }
    isUpdating = true
    defer { isUpdating = false }
    _ = try store()
    try await savePendingRun()
    try Task.checkCancellation()
    let session = WorkoutSession(store: snapshots)
    try await session.start()
    self.session = session
    elapsed = 0
    distanceMeters = nil
    lastMeasuredCadence = nil
    state = .active
    if healthExportEnabled {
      do {
        try healthKit.startWorkoutSession(at: .now)
      } catch {
        Self.logger.error(
          "Could not start Apple Health workout: \(error.localizedDescription, privacy: .private)")
      }
    }
    await endOrphanedActivities()
    let content = activityContent(elapsed: await session.activeElapsed)
    if ActivityAuthorizationInfo().areActivitiesEnabled {
      do {
        activityID = try Activity.request(
          attributes: RunActivityAttributes(), content: content, pushType: nil
        ).id
      } catch {
        Self.logger.error(
          "Could not start Live Activity: \(error.localizedDescription, privacy: .private)")
      }
    }
    await startSensors()
    checkpointTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .seconds(5))
        } catch {
          return
        }
        guard let self else { return }
        await self.checkpoint()
      }
    }
  }

  func togglePause() async throws {
    guard !isUpdating, let session else { return }
    isUpdating = true
    defer { isUpdating = false }
    if state == .paused {
      try await session.resume(distanceMeters: distanceMeters)
      state = .active
      healthKit.resumeWorkoutSession()
      await startSensors()
    } else {
      let startedAt = segmentStartedAt
      segmentStartedAt = nil
      defer { if state == .active { segmentStartedAt = startedAt } }
      try await session.pause(distanceMeters: distanceMeters)
      state = .paused
      healthKit.pauseWorkoutSession()
      await stopSensors()
    }
    elapsed = await session.activeElapsed
    state = await session.state
    await updateActivity(elapsed: elapsed)
  }

  func finish() async throws -> RunSummary? {
    guard !isUpdating, let session else { return nil }
    isUpdating = true
    defer { isUpdating = false }
    let startedAt = segmentStartedAt
    segmentStartedAt = nil
    defer { if state == .active { segmentStartedAt = startedAt } }
    let finished = try await session.finish(distanceMeters: distanceMeters)
    checkpointTask?.cancel()
    checkpointTask = nil
    state = .finished
    healthKit.endWorkoutSession()
    elapsed = finished.activeElapsed
    if let activityID {
      await Self.endActivities(id: activityID, content: activityContent(elapsed: elapsed))
    }
    activityID = nil
    await stopSensors()
    let record = try await store().record(
      finished, distanceMeters: distanceMeters, cadenceStepsPerMinute: lastMeasuredCadence)
    try snapshots.clear()
    self.session = nil
    healthExportFailed = false
    if healthExportEnabled, finished.finishReason == .userFinished {
      let distance = record.distanceMeters
      Task {
        refreshHealthAccess()
        do {
          try await healthKit.saveRun(finished, distanceMeters: distance)
        } catch {
          healthExportFailed = true
        }
      }
    }
    state = .idle
    return RunSummary(record: record)
  }

  func refreshHealthAccess() {
    healthWorkoutAccess = healthKit.canSaveWorkouts
  }

  func enableHealthExport() async throws {
    defer { refreshHealthAccess() }
    try await healthKit.requestAccess()
    preferences.set(true, forKey: Self.healthExportKey)
    healthExportEnabled = true
  }

  func updateElapsed() async {
    guard !isUpdating, state == .active, let session else { return }
    let value = await session.activeElapsed
    guard !isUpdating, state == .active, self.session === session else { return }
    elapsed = value
  }

  func checkpoint() async {
    guard !isUpdating, state == .active, let session else { return }
    do {
      try await session.checkpoint(distanceMeters: distanceMeters)
      let value = await session.activeElapsed
      if !isUpdating, self.session === session, state == .active {
        await updateActivity(elapsed: value, onlyIfDistanceChanged: true)
      }
    } catch {
      Self.logger.error(
        "Could not write workout checkpoint: \(error.localizedDescription, privacy: .private)")
    }
  }

  private func updateActivity(elapsed: TimeInterval, onlyIfDistanceChanged: Bool = false) async {
    guard let activityID else { return }
    await Self.publishActivity(
      id: activityID, content: activityContent(elapsed: elapsed),
      timestamp: .now, onlyIfDistanceChanged: onlyIfDistanceChanged)
  }

  @concurrent
  private static func publishActivity(
    id: String, content: ActivityContent<RunActivityAttributes.ContentState>,
    timestamp: Date, onlyIfDistanceChanged: Bool
  ) async {
    guard
      let activity = Activity<RunActivityAttributes>.activities.first(where: { $0.id == id }
      ),
      !onlyIfDistanceChanged
        || content.state.distanceMeters != activity.content.state.distanceMeters
    else { return }
    await activity.update(content, alertConfiguration: nil, timestamp: timestamp)
  }

  private func activityContent(elapsed: TimeInterval) -> ActivityContent<
    RunActivityAttributes.ContentState
  > {
    ActivityContent(
      state: .init(
        elapsed: elapsed,
        runningSince: state == .active ? Date.now.addingTimeInterval(-elapsed) : nil,
        distanceMeters: distanceMeters.map { ($0 / 10).rounded(.down) * 10 },
        averagePace: averagePace),
      staleDate: nil)
  }

  private func endOrphanedActivities() async {
    await Self.endActivities(id: nil, content: nil)
  }

  @concurrent
  private static func endActivities(
    id: String?, content: ActivityContent<RunActivityAttributes.ContentState>?
  ) async {
    for activity in Activity<RunActivityAttributes>.activities where id == nil || activity.id == id
    {
      await activity.end(content, dismissalPolicy: .immediate)
    }
  }

  private func startSensors() async {
    let startedAt = Date()
    segmentStartedAt = startedAt
    if canTrackLocation(), let events = try? await location.start() {
      locationTask = Task { [weak self] in
        for await event in events {
          guard !Task.isCancelled else { return }
          self?.receiveLocation(event, since: startedAt)
        }
      }
    }
    if let events = try? await cadence.start() {
      cadenceTask = Task { [weak self] in
        for await event in events {
          guard !Task.isCancelled, let self else { return }
          switch event {
          case .sample(let sample):
            let steps = sample.stepsPerSecond.map { $0 * 60 }
            self.cadenceStepsPerMinute = steps
            if let steps, steps > 0, let rounded = Int(exactly: steps.rounded()) {
              self.lastMeasuredCadence = rounded
            }
          case .unavailable:
            self.cadenceStepsPerMinute = nil
          }
        }
      }
    }
    heartRateTask = Task { [weak self, healthKit] in
      for await event in healthKit.liveHeartRate() {
        guard !Task.isCancelled, let self else { return }
        switch event {
        case .sample(let sample): self.heartRate = sample.beatsPerMinute
        case .unavailable: self.heartRate = nil
        }
      }
    }
  }

  private func stopSensors() async {
    segmentStartedAt = nil
    locationTask?.cancel()
    cadenceTask?.cancel()
    heartRateTask?.cancel()
    locationTask = nil
    cadenceTask = nil
    heartRateTask = nil
    previousLocation = nil
    pace = nil
    cadenceStepsPerMinute = nil
    heartRate = nil
    await location.stop()
    await cadence.stop()
  }

  private func receiveLocation(_ event: LocationEvent, since startedAt: Date) {
    guard state == .active, segmentStartedAt == startedAt else { return }
    switch event {
    case .sample(let sample):
      guard sample.timestamp >= startedAt, sample.horizontalAccuracy >= 0 else { return }
      var measuredSpeed: Double?
      if let previousLocation {
        guard sample.timestamp > previousLocation.timestamp else { return }
        let previous = CLLocation(
          latitude: previousLocation.latitude, longitude: previousLocation.longitude)
        let current = CLLocation(latitude: sample.latitude, longitude: sample.longitude)
        let meters = current.distance(from: previous)
        distanceMeters = (distanceMeters ?? 0) + meters
        measuredSpeed = meters / sample.timestamp.timeIntervalSince(previousLocation.timestamp)
      } else if distanceMeters == nil {
        distanceMeters = 0
      }
      previousLocation = sample
      pace = (sample.speed ?? measuredSpeed).flatMap { $0.isFinite && $0 > 0 ? 1_000 / $0 : nil }
    case .stationary:
      pace = nil
    case .accuracyReduced:
      break
    case .locationUnavailable, .authorizationDenied, .authorizationRestricted,
      .serviceSessionRequired:
      previousLocation = nil
      pace = nil
    }
  }

  private func savePendingRun() async throws {
    guard let snapshot = try snapshots.load(), let pending = snapshot.pendingRun else { return }
    _ = try await store().record(pending, distanceMeters: snapshot.distanceMeters)
    try snapshots.clear()
  }
}
