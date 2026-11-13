//
//  RunRecoveryTests.swift
//  RunnerTests
//
//  Created by Peter on 09/11/2026.
//

import CoreLocation
import Foundation
import RunnerCadence
import RunnerCadenceTesting
import RunnerEncounters
import RunnerEncountersTesting
import RunnerHealthKit
import RunnerLocation
import RunnerSession
import RunnerSessionTesting
import RunnerStore
import Testing

@testable import Runner

struct RunRecoveryTests {

  @Test
  func paceUsesMinutesAndSecondsEvenAboveOneHour() {
    #expect(RunHistoryMetrics.paceTime(303.25) == "5:03")
    #expect(RunHistoryMetrics.paceTime(4_005.25) == "66:45")
    #expect(RunHistoryMetrics.paceTime(7_200) == "120:00")
    #expect(RunHistoryMetrics.paceTime(7_201) == nil)
    #expect(RunHistoryMetrics.paceTime(90_023) == nil)
    #expect(RunHistoryMetrics.paceTime(0) == nil)
  }

  @Test
  func averagePaceTruncatesSecondsAndCapsExtremeValues() {
    #expect(RunHistoryMetrics.paceMinutes(3_405) == "56")
    #expect(RunHistoryMetrics.paceMinutes(7_200) == "120")
    #expect(RunHistoryMetrics.paceMinutes(7_201) == "120+")
    #expect(RunHistoryMetrics.paceMinutes(326_568) == "120+")
    #expect(RunHistoryMetrics.paceMinutes(0) == nil)
  }

  @MainActor
  @Test
  func finishWhilePausedSavesTheLastMeasuredCadence() async throws {
    let store = RunStore(modelContainer: try AppDatabase.ephemeral().container)
    let sample = CadenceSampleModel(currentCadence: NSNumber(value: 158.0 / 60), timestamp: .now)
    let live = RunLiveViewModel(
      snapshots: InMemorySessionSnapshotStore(), store: { store },
      location: LocationTracker(source: TestLocationFeed()),
      cadence: CadenceTracker(source: MockCadenceUpdateSource(events: [.sample(sample)])),
      healthKit: TestHealthGateway(), canTrackLocation: { false })

    try await live.start()
    let deadline = ContinuousClock.now + .seconds(2)
    while live.cadenceStepsPerMinute == nil, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    try #require(live.cadenceStepsPerMinute != nil)
    try await live.togglePause()
    #expect(live.cadenceStepsPerMinute == nil)
    let summary = try await live.finish()
    #expect(summary?.cadenceStepsPerMinute == 158)
    #expect(try await store.recentRuns().first?.cadenceStepsPerMinute == 158)
  }

  @MainActor
  @Test
  func liveEncounterCountsSurviveFinishingAndReloadingHistory() async throws {
    let store = RunStore(modelContainer: try AppDatabase.ephemeral().container)
    let scanner = MockProximityScanner(sightings: [
      ProximitySighting(
        peer: EncounterPeer(peripheralID: UUID(), broadcastID: nil), rssi: -55, at: .now)
    ])
    let tracker = EncounterTracker(
      scanner: scanner, advertiser: MockProximityAdvertiser(), haptics: MockEncounterHaptics(),
      rotation: RotatingIdentifier(root: UUID()))
    let live = RunLiveViewModel(
      snapshots: InMemorySessionSnapshotStore(), store: { store },
      location: LocationTracker(source: TestLocationFeed()),
      cadence: CadenceTracker(source: LiveCadenceUpdateSource(availabilityChecker: { false })),
      healthKit: LiveHealthKitStore(), canTrackLocation: { false }, encounters: tracker)

    try await live.start()
    try await live.togglePause()
    #expect(live.runEncounters?.new == 1)
    try await live.togglePause()
    let summary = try #require(try await live.finish())
    #expect(summary.encounters == RunEncounters(new: 1, again: 0, together: 0))
    let saved = try #require(try await store.recentRuns().first)
    #expect(RunSummary(record: saved).encounters == summary.encounters)
  }

  @MainActor
  @Test
  func locationDistanceExcludesThePausedSegmentAndReachesHistory() async throws {
    let store = RunStore(modelContainer: try AppDatabase.ephemeral().container)
    let source = TestLocationFeed()
    let live = RunLiveViewModel(
      snapshots: InMemorySessionSnapshotStore(), store: { store },
      location: LocationTracker(source: source),
      cadence: CadenceTracker(source: LiveCadenceUpdateSource(availabilityChecker: { false })),
      healthKit: LiveHealthKitStore(), canTrackLocation: { true })

    try await live.start()
    await source.send(longitude: 0)
    await source.send(longitude: 0.001)
    try await waitForDistance(in: live, greaterThan: 100)
    let firstSegment = try #require(live.distanceMeters)
    #expect(live.pace != nil)

    try await live.togglePause()
    await source.send(longitude: 0.01)
    #expect(live.distanceMeters == firstSegment)
    try await live.togglePause()
    await source.send(longitude: 0.02)
    await source.send(longitude: 0.021)
    try await waitForDistance(in: live, greaterThan: firstSegment + 100)
    let finished = try await live.finish()
    let distance = try #require(finished?.distanceMeters)
    #expect((220...225).contains(distance))
    let saved = try await store.recentRuns()
    #expect(saved.first?.distanceMeters == distance)
  }

  @MainActor
  private func waitForDistance(in live: RunLiveViewModel, greaterThan minimum: Double) async throws
  {
    let deadline = ContinuousClock.now + .seconds(2)
    while (live.distanceMeters ?? 0) <= minimum, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    try #require((live.distanceMeters ?? 0) > minimum)
  }

  @MainActor
  @Test
  func liveRunPausesFinishesAndRecoversThroughLocalHistory() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = try AppDatabase.persistent(in: directory)
    let store = RunStore(modelContainer: database.container)
    let drafts = InMemorySessionSnapshotStore()
    let historyAvailability = HistoryAvailability()
    let live = RunLiveViewModel(
      snapshots: drafts,
      store: {
        guard historyAvailability.canWrite else { throw AppDatabaseError.noAppGroupContainer }
        return store
      },
      location: LocationTracker(source: LiveLocationUpdateSource()),
      cadence: CadenceTracker(source: LiveCadenceUpdateSource(availabilityChecker: { false })),
      healthKit: LiveHealthKitStore(), canTrackLocation: { false })

    try await live.start()
    #expect(live.state == .active)
    await live.checkpoint()
    #expect(try drafts.load()?.state == .active)
    try await live.togglePause()
    #expect(live.state == .paused)
    let pausedElapsed = live.elapsed
    await live.updateElapsed()
    #expect(live.elapsed == pausedElapsed)
    try await live.togglePause()
    #expect(live.state == .active)
    historyAvailability.canWrite = false
    await #expect(throws: AppDatabaseError.noAppGroupContainer) {
      try await live.finish()
    }
    #expect(live.state == .finished)
    let pendingRun = try drafts.load()?.pendingRun
    #expect(pendingRun?.finishReason == .userFinished)
    historyAvailability.canWrite = true
    let result = try await live.finish()
    let finished = try #require(result)
    #expect(finished.id == pendingRun?.id)
    #expect(try drafts.load() == nil)
    let reopened = RunStore(modelContainer: try AppDatabase.persistent(in: directory).container)
    let saved = try await reopened.recentRuns()
    #expect(saved.map { RunSummary(record: $0) } == [finished])

    let interrupted = snapshot(state: .active)
    try drafts.save(interrupted)
    try await live.recover()
    try await live.recover()
    let recovered = try await store.recentRuns()
    #expect(recovered.count == 2)
    #expect(recovered.first { $0.id == interrupted.id }?.activeElapsed == 60)
    #expect(try drafts.load() == nil)
  }

  @MainActor
  @Test
  func healthExportRequiresOptInAndSkipsInterruptedRuns() async throws {
    let suite = "RunRecoveryTests.\(UUID().uuidString)"
    let preferences = try #require(UserDefaults(suiteName: suite))
    defer { preferences.removePersistentDomain(forName: suite) }
    let store = RunStore(modelContainer: try AppDatabase.ephemeral().container)
    let drafts = InMemorySessionSnapshotStore()
    let health = TestHealthGateway()
    func makeLive() -> RunLiveViewModel {
      RunLiveViewModel(
        snapshots: drafts, store: { store },
        location: LocationTracker(source: TestLocationFeed()),
        cadence: CadenceTracker(source: LiveCadenceUpdateSource(availabilityChecker: { false })),
        healthKit: health, preferences: preferences, canTrackLocation: { false })
    }
    let initial = makeLive()
    try await initial.start()
    let privateRun = try await initial.finish()
    #expect(privateRun != nil)
    try await initial.enableHealthExport()

    let live = makeLive()
    #expect(live.healthExportEnabled)
    let interrupted = snapshot(state: .active)
    try drafts.save(interrupted)
    try await live.recover()
    #expect(health.workoutTransitions.isEmpty)
    try await live.start()
    try await live.togglePause()
    try await live.togglePause()
    let finished = try await live.finish()
    let finishedID = try #require(finished?.id)
    let deadline = ContinuousClock.now + .seconds(2)
    while await health.savedIDs.isEmpty, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(await health.savedIDs == [finishedID])
    #expect(health.workoutTransitions == [.active, .paused, .active, .finished])
    let saved = try await store.recentRuns()
    #expect(saved.contains { $0.id == interrupted.id })
    #expect(saved.contains { $0.id == privateRun?.id })
  }

  private func snapshot(state: SessionState) -> SessionSnapshotModel {
    SessionSnapshotModel(
      id: UUID(), startedAtWall: Date(), accumulatedActive: 60, state: state,
      batteryLevelAtStart: nil, batteryLevel: nil, checkpointAtWall: Date())
  }

  @Test
  func emptyStoreReturnsNil() throws {
    #expect(try RunRecovery().recover(in: InMemorySessionSnapshotStore()) == nil)
  }

  @Test
  func activeSnapshotCutsARun() throws {
    let store = InMemorySessionSnapshotStore()
    try store.save(snapshot(state: .active))
    let cut = try RunRecovery().recover(in: store)
    #expect(cut != nil)
    #expect(try store.load() == nil)
  }

  @Test
  func finishedSnapshotYieldsNothing() throws {
    let store = InMemorySessionSnapshotStore()
    try store.save(snapshot(state: .finished))
    #expect(try RunRecovery().recover(in: store) == nil)
  }
}

private actor TestLocationFeed: LocationUpdateSource {

  private var handler: (@Sendable (LocationEvent) -> Void)?

  func start(handler: @Sendable @escaping (LocationEvent) -> Void) {
    self.handler = handler
  }

  func stop() {
    handler = nil
  }

  func send(longitude: Double) {
    let location = CLLocation(
      coordinate: .init(latitude: 0, longitude: longitude), altitude: 0,
      horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: .now)
    handler?(.sample(LocationSampleModel(from: location)))
  }
}

@MainActor
private final class HistoryAvailability {

  var canWrite = true
}

private actor TestHealthGateway: HealthKitGateway {

  nonisolated var canSaveWorkouts: Bool { true }

  private(set) var savedIDs: [UUID] = []

  @MainActor private(set) var workoutTransitions: [SessionState] = []
  @MainActor private var workoutActive = false

  @MainActor func startWorkoutSession(at date: Date) throws {
    workoutActive = true
    workoutTransitions.append(.active)
  }

  @MainActor func pauseWorkoutSession() {
    workoutTransitions.append(.paused)
  }

  @MainActor func resumeWorkoutSession() {
    workoutTransitions.append(.active)
  }

  @MainActor func endWorkoutSession() {
    guard workoutActive else { return }
    workoutActive = false
    workoutTransitions.append(.finished)
  }

  func requestAccess() async throws {}

  func saveRun(_ run: FinishedRunModel, distanceMeters: Double?) async throws {
    savedIDs.append(run.id)
  }

  func readHeartRate(from start: Date, to end: Date) async throws -> [HeartRateSample] { [] }

  nonisolated func liveHeartRate() -> AsyncStream<HeartRateEvent> {
    AsyncStream { $0.finish() }
  }
}
