import CoreMotion
import Foundation
import RunnerAuth
import RunnerGateway
import RunnerSession

/// Real sensor evidence from a finished workout; missing steps cannot be attested.
nonisolated struct GoalRunEvidence: Codable, Sendable {
  let id: UUID
  let startedAt: Int
  let endedAt: Int
  let activeSeconds: Int
  let distanceM: Int
  let kilometerSplits: [Int]
  let steps: Int

  private enum CodingKeys: String, CodingKey {
    case id, steps
    case startedAt = "started_at"
    case endedAt = "ended_at"
    case activeSeconds = "active_seconds"
    case distanceM = "distance_m"
    case kilometerSplits = "km_splits_s"
  }
}

nonisolated struct GoalRunProof: Codable, Sendable {
  let json: String
  let signature: String
}

nonisolated enum GoalEvidenceError: Error {
  case missingStepEvidence
}

/// What the last run check found, phrased for the goal card.
nonisolated enum GoalUnlockOutcome: Sendable, Equatable {
  /// No goal is locked.
  case noGoal
  /// No run is waiting; carries why the latest run could not be used.
  case noRun(rejection: String?)
  /// Saved runs exist, but none beats the locked goal.
  case noQualifyingRun
  /// A qualifying run could not be verified.
  case refused(String)
  /// The server signed a run proof that beats this goal: it can be withdrawn.
  case proven(goalID: UUID)

  var note: String? {
    switch self {
    case .noGoal, .proven: nil
    case .noRun(let rejection): rejection.map { "Last run can’t count: \($0)" }
    case .noQualifyingRun: "Your recent runs don’t beat this goal yet."
    case .refused(let reason): "Run not verified: \(reason)"
    }
  }
}

/// Finished-run evidence kept on device until the locked goal can use it,
/// and the server proof for the run that beats it. Checking a run only
/// talks to the Worker; the chain unlock happens on withdraw.
actor GoalEvidence {
  private let keychain: any SecureStore
  private let lastProofKey = "goals.last-run-proof"
  private let candidateKey = "goals.run-candidate"
  private let rejectionKey = "goals.last-run-rejection"
  private var checking = false
  private var runCandidates: [RunCandidate]?
  private var persistedProof: CachedProof?

  init(keychain: any SecureStore) {
    self.keychain = keychain
  }

  /// Keeps real sensor intervals local until a current goal can use them.
  func recordRun(_ run: FinishedRunModel, distanceMeters: Double?, splits: [Double]) async throws {
    let candidate: RunCandidate
    do {
      candidate = try RunCandidate(run: run, distanceMeters: distanceMeters, splits: splits)
    } catch {
      UserDefaults.standard.set(error.message, forKey: rejectionKey)
      return
    }
    UserDefaults.standard.removeObject(forKey: rejectionKey)
    try await loadCandidates()
    guard var candidates = runCandidates,
      !candidates.contains(where: { $0.id == candidate.id })
    else { return }
    candidates.insert(candidate, at: 0)
    try await saveCandidates(candidates)
  }

  /// Get the server's run proof for a saved run that beats `goal`.
  /// Nil while another check is running.
  func check(goal: GoalRecord?, using service: GoalService) async throws -> GoalUnlockOutcome? {
    guard !checking else { return nil }
    checking = true
    defer { checking = false }

    guard let goal, goal.state == "locked" else { return .noGoal }
    if try await cachedProof()?.goalID == goal.id { return .proven(goalID: goal.id) }
    try await loadCandidates()
    let candidates = runCandidates ?? []
    guard !candidates.isEmpty else {
      return .noRun(rejection: UserDefaults.standard.string(forKey: rejectionKey))
    }

    let matching = candidates.filter { $0.qualifies(for: goal, lockedAt: goal.lockedAt) }
    guard !matching.isEmpty else { return .noQualifyingRun }
    var refusal = "the run couldn’t be checked."
    for var candidate in matching {
      if candidate.steps == nil {
        do {
          candidate.steps = try await candidate.measuredSteps()
        } catch GoalEvidenceError.missingStepEvidence {
          return .refused("allow Motion & Fitness for Ije in Settings.")
        }
        guard var current = runCandidates,
          let index = current.firstIndex(where: { $0.id == candidate.id })
        else { continue }
        current[index] = candidate
        try await saveCandidates(current)
      }
      guard let evidence = candidate.evidence else {
        refusal = "average cadence must be 100–230 steps a minute."
        continue
      }
      let proof: GoalRunProof
      do {
        proof = try await service.attest(evidence)
      } catch GatewayError.server(let status, let code) where status == 422 || status == 409 {
        refusal = Self.serverReason(code)
        continue
      }
      let fresh = CachedProof(runID: evidence.id, proof: proof, goalID: goal.id)
      persistedProof = fresh
      try await keychain.save(JSONEncoder().encode(fresh), forKey: lastProofKey)
      return .proven(goalID: goal.id)
    }
    return .refused(refusal)
  }

  /// The proof that beats `goalID`, if a check produced one.
  func proof(for goalID: UUID) async throws -> GoalRunProof? {
    guard let cached = try await cachedProof(), cached.goalID == goalID else { return nil }
    return cached.proof
  }

  /// The goal unlocked on chain: runs up to the proven one are spent.
  func didUnlock(_ goalID: UUID) async throws {
    guard let cached = try await cachedProof(), cached.goalID == goalID else { return }
    try await loadCandidates()
    let proven = runCandidates?.first { $0.id == cached.runID }
    let remaining = (runCandidates ?? []).filter { $0.startedAt > (proven?.startedAt ?? 0) }
    try await saveCandidates(remaining)
  }

  /// The Worker's eligibility codes (`apps/api/src/eligibility.ts`).
  private static func serverReason(_ code: String) -> String {
    switch code {
    case "too_short": "the run is too short."
    case "too_old": "runs must be verified within 6 hours."
    case "bad_splits": "the kilometre splits don’t add up."
    case "too_many_pauses": "paused for more than 30 minutes."
    case "pace_out_of_range": "each kilometre must take 2:30–20:00."
    case "cadence_out_of_range": "average cadence must be 100–230 steps a minute."
    case "too_soon": "one verified run every 4 hours."
    default: "the server refused it (\(code))."
    }
  }

  private func loadCandidates() async throws {
    if runCandidates == nil {
      let stored: [RunCandidate]
      if let data = try await keychain.load(forKey: candidateKey) {
        stored = try JSONDecoder().decode([RunCandidate].self, from: data)
      } else {
        stored = []
      }
      if runCandidates == nil { runCandidates = stored }
    }
    let minimumEnd = Int(Date().timeIntervalSince1970) - 6 * 3_600
    if let candidates = runCandidates {
      let cachedRunID = try await cachedProof()?.runID
      let pending = (runCandidates ?? candidates)
        .filter { $0.endedAt >= minimumEnd || $0.id == cachedRunID }
      if pending.count < (runCandidates ?? candidates).count { try await saveCandidates(pending) }
    }
  }

  private func saveCandidates(_ candidates: [RunCandidate]) async throws {
    let retained = Array(candidates.prefix(8))
    runCandidates = retained
    if retained.isEmpty {
      try await keychain.delete(forKey: candidateKey)
    } else {
      try await keychain.save(JSONEncoder().encode(retained), forKey: candidateKey)
    }
  }

  private func cachedProof() async throws -> CachedProof? {
    if let persistedProof { return persistedProof }
    guard let data = try await keychain.load(forKey: lastProofKey) else { return nil }
    return try JSONDecoder().decode(CachedProof.self, from: data)
  }

  private struct CachedProof: Codable {
    let runID: UUID
    let proof: GoalRunProof
    /// The goal this proof was checked against (nil for older caches).
    var goalID: UUID?
  }
}

/// Wall-time segments from the workout state machine; telemetry is never
/// fabricated from average cadence or interpolated between pauses.
private nonisolated struct RunCandidate: Codable, Sendable {
  let id: UUID
  let startedAt: Int
  let endedAt: Int
  let activeSeconds: Int
  let distanceM: Int
  let kilometerSplits: [Int]
  let activeIntervals: [DateInterval]
  var steps: Int?

  struct Rejection: Error {
    let message: String
  }

  init(run: FinishedRunModel, distanceMeters: Double?, splits: [Double]) throws(Rejection) {
    guard run.finishReason == .userFinished else {
      throw Rejection(message: "it didn’t end with Finish.")
    }
    guard let distanceMeters,
      let distance = Int(exactly: distanceMeters.rounded(.down)),
      (2_500...500_000).contains(distance)
    else {
      throw Rejection(message: "runs must cover at least 2.5 km.")
    }
    guard let start = Int(exactly: run.startedAtWall.timeIntervalSince1970.rounded(.down)),
      let end = Int(exactly: run.finishedAtWall.timeIntervalSince1970.rounded(.down)),
      let elapsed = Int(exactly: run.activeElapsed.rounded(.down)),
      start >= 0, end <= 4_102_444_800, end > start,
      elapsed > 0, elapsed <= end - start
    else {
      throw Rejection(message: "its start and finish times don’t line up.")
    }
    guard end - start - elapsed <= 1_800 else {
      throw Rejection(message: "it was paused for more than 30 minutes.")
    }
    guard splits.count == distance / 1_000 else {
      throw Rejection(
        message: "it recorded \(splits.count) of \(distance / 1_000) kilometre splits.")
    }

    // Round cumulative crossings so independently rounded splits cannot
    // add up to more than the recorded active time.
    var elapsedAtCrossing: TimeInterval = 0
    var lastCrossing = 0
    var validatedSplits: [Int] = []
    for split in splits {
      elapsedAtCrossing += split
      guard let crossing = Int(exactly: elapsedAtCrossing.rounded(.down)),
        crossing <= elapsed, crossing >= lastCrossing,
        (150...1_200).contains(crossing - lastCrossing)
      else {
        throw Rejection(message: "each kilometre must take 2:30–20:00.")
      }
      validatedSplits.append(crossing - lastCrossing)
      lastCrossing = crossing
    }

    let pace = Double(elapsed) * 1_000 / Double(distance)
    guard (150...1_200).contains(pace) else {
      throw Rejection(message: "average pace must be 2:30–20:00 per km.")
    }
    guard
      let intervals = Self.activeIntervals(
        from: run.startedAtWall, to: run.finishedAtWall, excluding: run.pauses)
    else {
      throw Rejection(message: "its pauses don’t line up with the run.")
    }

    id = run.id
    startedAt = start
    endedAt = end
    activeSeconds = elapsed
    distanceM = distance
    kilometerSplits = validatedSplits
    activeIntervals = intervals
  }

  func qualifies(for goal: GoalRecord, lockedAt: Int) -> Bool {
    guard startedAt >= lockedAt, distanceM >= Int(goal.distanceM) else { return false }
    guard let limit = goal.maxSeconds else { return true }
    return activeSeconds * Int(goal.distanceM) <= Int(limit) * distanceM
  }

  var evidence: GoalRunEvidence? {
    guard let steps, (0...10_000_000).contains(steps),
      (100...230).contains(Double(steps) * 60 / Double(activeSeconds))
    else { return nil }
    return GoalRunEvidence(
      id: id, startedAt: startedAt, endedAt: endedAt, activeSeconds: activeSeconds,
      distanceM: distanceM, kilometerSplits: kilometerSplits, steps: steps)
  }

  private static func activeIntervals(
    from start: Date, to end: Date, excluding pauses: [DateInterval]
  ) -> [DateInterval]? {
    var startOfSegment = start
    var intervals: [DateInterval] = []
    for pause in pauses {
      guard pause.start >= startOfSegment, pause.end <= end else { return nil }
      if pause.start > startOfSegment {
        intervals.append(DateInterval(start: startOfSegment, end: pause.start))
      }
      startOfSegment = pause.end
    }
    if end > startOfSegment { intervals.append(DateInterval(start: startOfSegment, end: end)) }
    return intervals.isEmpty ? nil : intervals
  }

  func measuredSteps() async throws -> Int {
    guard CMPedometer.isStepCountingAvailable(), CMPedometer.authorizationStatus() == .authorized
    else { throw GoalEvidenceError.missingStepEvidence }
    let pedometer = CMPedometer()
    var steps = 0
    for interval in activeIntervals {
      try Task.checkCancellation()
      let count: Int = try await withCheckedThrowingContinuation { continuation in
        pedometer.queryPedometerData(from: interval.start, to: interval.end) { data, error in
          if let error {
            continuation.resume(throwing: error)
          } else if let data {
            continuation.resume(returning: data.numberOfSteps.intValue)
          } else {
            continuation.resume(throwing: GoalEvidenceError.missingStepEvidence)
          }
        }
      }
      guard (0...10_000_000 - steps).contains(count) else {
        throw GoalEvidenceError.missingStepEvidence
      }
      steps += count
    }
    return steps
  }
}
