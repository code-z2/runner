import Foundation
import Observation
import RunnerPacePilot
import RunnerStore

@MainActor
@Observable
final class RunCoach {
  static let qualifyingRunCount = 10
  static let minimumRunDistance = 2_500.0

  private let voice = KokoroCueRenderer()
  private let rhythm: RhythmCueRenderer
  private var preloadTask: Task<Void, Never>?
  private var scheduler: CueScheduler?
  private var cueTask: Task<Void, Never>?
  private var pendingSample: CoachSample?
  private(set) var state: CoachState = .idle
  private var context = CoachContext(goalDistance: nil, cadenceBaseline: nil)

  init() {
    rhythm = RhythmCueRenderer(voice: voice)
  }

  func begin(goalKilometers: Double?, history: [RunRecordSnapshot]) {
    silence()
    state = .idle
    let eligible = history.count >= Self.qualifyingRunCount
    let readings = history.compactMap(\.cadenceStepsPerMinute).filter { $0 > 0 }.sorted()
    let baseline =
      eligible && !readings.isEmpty
      ? (Double(readings[(readings.count - 1) / 2]) + Double(readings[readings.count / 2])) / 2
      : nil
    context = CoachContext(
      goalDistance: goalKilometers.map { $0 * 1_000 }, cadenceBaseline: baseline)
    scheduler = CueScheduler(
      brain: RulesCoachBrain(adaptiveEnabled: eligible), renderer: rhythm,
      preferences: CoachPreferences(masterEnabled: true, beatsEnabled: baseline != nil),
      beatTarget: baseline)
    startPreload()
  }

  /// Start the ~9s model load without blocking the caller: the visual
  /// countdown gives it a head start, and the service keeps one loaded model.
  func startPreload() {
    guard preloadTask == nil else { return }
    preloadTask = Task { [voice] in
      await voice.preload()
    }
  }

  /// The 3-2-1 stays visual: ticks only, never spoken.
  static func playCountdown(
    onTick: (Int) -> Void = { _ in }
  ) async throws {
    let clock = ContinuousClock()
    for count in [3, 2, 1] {
      try Task.checkCancellation()
      let deadline = clock.now + .seconds(1)
      onTick(count)
      try Task.checkCancellation()
      if clock.now < deadline {
        try await clock.sleep(until: deadline)
      }
    }
    try Task.checkCancellation()
  }
  var isCoaching: Bool { scheduler != nil }

  func ingest(_ sample: CoachSample) {
    guard let scheduler else { return }
    pendingSample = sample
    guard cueTask?.isCancelled != false else { return }
    let previous = cueTask
    let context = context
    cueTask = Task { [weak self] in
      await previous?.value
      while !Task.isCancelled, let self, let sample = self.pendingSample {
        self.pendingSample = nil
        await scheduler.ingest(sample, context: context)
        let state = await scheduler.state
        guard !Task.isCancelled else { return }
        self.state = state
      }
      if !Task.isCancelled { self?.cueTask = nil }
    }
  }

  func silence() {
    pendingSample = nil
    cueTask?.cancel()
  }

  func end() {
    preloadTask?.cancel()
    preloadTask = nil
    silence()
    scheduler = nil
    state = .idle
  }

}

/// Plays a short four-step pattern. The next measured cadence decides
/// whether guidance repeats, so speech and rhythm share one playback slot.
private struct RhythmCueRenderer: CueRenderer {
  let voice: any CueRenderer

  func render(_ cue: CoachCue) async { await voice.render(cue) }

  func setBeatInterval(_ interval: TimeInterval?) async {
    guard let interval, interval.isFinite, (0.2...1).contains(interval),
      !Task.isCancelled
    else { return }

    let sampleRate = 24_000
    let framesPerStep = Int(interval * Double(sampleRate))
    let tickLength = sampleRate / 25
    var samples = [Float](repeating: 0, count: 3 * framesPerStep + tickLength)
    for step in 0..<4 {
      let frequency = step.isMultiple(of: 2) ? 780.0 : 540.0
      for frame in 0..<tickLength {
        let progress = Double(frame) / Double(tickLength)
        let phase = 2 * Double.pi * frequency * Double(frame) / Double(sampleRate)
        samples[step * framesPerStep + frame] = Float(sin(phase) * sin(.pi * progress) * 0.2)
      }
    }
    try? await CoachAudioPlayback.play(samples)
  }
}
