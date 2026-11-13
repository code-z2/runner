//
//  RunStore.swift
//  RunnerStore
//
//  Created by Peter on 07/11/2026.
//

import Foundation
import RunnerSession
import SwiftData

/// Device-only run history. The actor executor makes record idempotent:
/// the same run ID can never insert twice, no matter how often it is retried.
@ModelActor
public actor RunStore {

  public func record(
    _ run: FinishedRunModel,
    distanceMeters: Double?
  ) throws -> RunRecordSnapshot {
    let runID = run.id
    let existing: [RunRecordModel]
    do {
      var descriptor = FetchDescriptor<RunRecordModel>(
        predicate: #Predicate { $0.runID == runID }
      )
      descriptor.fetchLimit = 1
      existing = try modelContext.fetch(descriptor)
    } catch {
      throw StoreError.fetchFailed
    }
    if let found = existing.first {
      return RunRecordSnapshot(model: found)
    }
    let model = RunRecordModel(
      runID: runID,
      startedAt: run.startedAtWall,
      activeElapsed: run.activeElapsed,
      distanceMeters: distanceMeters,
      finishReasonRaw: String(describing: run.finishReason),
      batteryLevelAtStart: run.batteryLevelAtStart,
      batteryLevelAtEnd: run.batteryLevelAtEnd,
      recordedAt: Date()
    )
    modelContext.insert(model)
    do {
      try modelContext.save()
    } catch {
      throw StoreError.saveFailed
    }
    return RunRecordSnapshot(model: model)
  }

  public func recentRuns(limit: Int = 20) throws -> [RunRecordSnapshot] {
    var descriptor = FetchDescriptor<RunRecordModel>(
      sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    let models: [RunRecordModel]
    do {
      models = try modelContext.fetch(descriptor)
    } catch {
      throw StoreError.fetchFailed
    }
    return models.map(RunRecordSnapshot.init(model:))
  }

  public func personalBests() throws -> PersonalBestsSnapshot {
    let descriptor = FetchDescriptor<RunRecordModel>()
    let models: [RunRecordModel]
    do {
      models = try modelContext.fetch(descriptor)
    } catch {
      throw StoreError.fetchFailed
    }
    let longest = models.max(by: { a, b in
      if (a.distanceMeters ?? 0) != (b.distanceMeters ?? 0) {
        return (a.distanceMeters ?? 0) < (b.distanceMeters ?? 0)
      }
      return a.activeElapsed < b.activeElapsed
    })
    let paced = models.compactMap { model -> Double? in
      guard let distance = model.distanceMeters, distance >= 1_000, distance > 0 else {
        return nil
      }
      return model.activeElapsed / distance
    }
    return PersonalBestsSnapshot(
      longest: longest.map(RunRecordSnapshot.init(model:)),
      fastestPaceSecondsPerMeter: paced.min(),
      totalRuns: models.count,
      totalActiveTime: models.reduce(0) { $0 + $1.activeElapsed }
    )
  }
}
