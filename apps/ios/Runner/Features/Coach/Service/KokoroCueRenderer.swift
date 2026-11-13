import Foundation
import RunnerPacePilot

/// Speaks cues with the bundled Kokoro INT8 voice, falling back to the
/// system voice when the model is missing or fails. Best-effort throughout:
/// a cue that cannot be spoken is skipped, never retried.
@MainActor
final class KokoroCueRenderer: CueRenderer {
  private let service: KokoroBenchmarkService
  private let apple = SystemSpeechRenderer()
  private let bundledModel = KokoroBenchmarkService.bundledZip(for: .int8)
  private var ready = false

  init(
    modelsDirectory: URL? = KokoroBenchmarkService.defaultModelsDirectory()
  ) {
    service = KokoroBenchmarkService(
      modelsDirectory: modelsDirectory ?? FileManager.default.temporaryDirectory)
  }

  /// Start the ~9s cold load early (visual countdown, run start) without
  /// blocking the caller. Safe to call repeatedly; the service keeps one
  /// loaded model and the actor serializes concurrent loads.
  func preload() async {
    guard let bundledModel, Self.supportsKokoro else { return }
    do {
      try await service.load(.int8, from: bundledModel)
      ready = true
    } catch {
      ready = false
    }
  }

  func render(_ cue: CoachCue) async {
    if ready, await renderKokoro(cue) { return }
    guard !Task.isCancelled else { return }
    await apple.render(cue)
  }

  func setBeatInterval(_ interval: TimeInterval?) async {
    // Beats ride the wrapper's tick path, as with the system voice.
  }

  private func renderKokoro(_ cue: CoachCue) async -> Bool {
    do {
      let synthesis = try await service.synthesize(.int8, text: cue.text)
      try await CoachAudioPlayback.play(synthesis.samples)
      return true
    } catch {
      return false
    }
  }

  private static var supportsKokoro: Bool {
    #if targetEnvironment(simulator)
      return false
    #else
      var system = utsname()
      guard uname(&system) == 0 else { return false }
      let identifier = withUnsafeBytes(of: &system.machine) {
        String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self)
      }
      return supportsKokoro(deviceIdentifier: identifier)
    #endif
  }

  nonisolated static func supportsKokoro(deviceIdentifier: String) -> Bool {
    guard deviceIdentifier.hasPrefix("iPhone") else { return false }
    let fields = deviceIdentifier.dropFirst("iPhone".count)
      .split(separator: ",", omittingEmptySubsequences: false)
    guard fields.count == 2, let family = Int(fields[0]), let model = Int(fields[1]),
      model > 0
    else { return false }
    return family >= 15 || (family == 14 && (model == 7 || model == 8))
  }
}
