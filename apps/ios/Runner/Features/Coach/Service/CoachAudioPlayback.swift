import AVFoundation
import Foundation
import RunnerPacePilot

@MainActor
enum CoachAudioPlayback {
  static func play(_ samples: [Float]) async throws {
    try Task.checkCancellation()
    guard !samples.isEmpty, samples.allSatisfy({ $0.isFinite }),
      samples.contains(where: { abs($0) > 0.0001 }),
      let format = AVAudioFormat(
        standardFormatWithSampleRate: 24_000, channels: 1),
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
      let channel = buffer.floatChannelData?[0]
    else { throw CocoaError(.fileReadCorruptFile) }

    buffer.frameLength = buffer.frameCapacity
    samples.withUnsafeBufferPointer {
      if let source = $0.baseAddress { channel.update(from: source, count: $0.count) }
    }

    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    let audio = AudioSessionPolicy.voicePrompt
    // setActive on the main thread stalls UI (and warns) while a session
    // is live — both edges of the session dance hop off-main.
    try await Task.detached(priority: .userInitiated) { try audio.apply() }.value
    do {
      try Task.checkCancellation()
      try engine.start()
      let completed = AsyncStream<Void>.makeStream()
      player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in
        completed.continuation.finish()
      }
      player.play()
      for await _ in completed.stream {}
    } catch {
      player.stop()
      engine.stop()
      await Task.detached(priority: .userInitiated) { try? audio.release() }.value
      throw error
    }
    player.stop()
    engine.stop()
    await Task.detached(priority: .userInitiated) { try? audio.release() }.value
    try Task.checkCancellation()
  }
}
