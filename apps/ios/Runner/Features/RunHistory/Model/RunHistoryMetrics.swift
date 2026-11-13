import Foundation

struct RunHistoryMetrics {

  let runs: [RunSummary]

  var longest: Double? {
    runs.compactMap { Self.kilometers($0.distanceMeters) }.max()
  }

  func fastest(at meters: Double) -> TimeInterval? {
    runs.compactMap { run -> TimeInterval? in
      // History stores total distance and elapsed time only. A longer run
      // cannot establish a 5K or 10K split without its split times.
      guard let distance = run.distanceMeters, abs(distance - meters) < 5,
        run.elapsed.isFinite, run.elapsed > 0
      else { return nil }
      return run.elapsed
    }.min()
  }

  static func kilometers(_ meters: Double?) -> Double? {
    guard let meters, meters.isFinite, meters > 0 else { return nil }
    return meters / 1_000
  }

  static func time(_ seconds: TimeInterval) -> String? {
    guard seconds.isFinite, seconds >= 0, seconds < Double(Int64.max) else { return nil }
    let rounded = seconds.rounded()
    return Duration.seconds(rounded).formatted(
      .time(pattern: rounded >= 3_600 ? .hourMinuteSecond : .minuteSecond))
  }
}
