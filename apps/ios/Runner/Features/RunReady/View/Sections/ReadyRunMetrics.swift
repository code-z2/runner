import RunnerUI
import SwiftUI

struct ReadyRunMetrics: View {
  let run: RunSummary
  let vertical: Bool

  @Environment(\.locale) private var locale

  var body: some View {
    let kilometers = run.distanceMeters.map { $0 / 1_000 }.flatMap {
      $0.isFinite && $0 > 0 ? $0 : nil
    }
    let distance = kilometers?.formatted(.number.precision(.fractionLength(2)).locale(locale))
    let time = formattedTime(run.elapsed)
    let pace = kilometers.flatMap { formattedTime(run.elapsed / $0) }

    if vertical {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        RunMetric(label: "Distance", value: distance, unit: "km")
        RunMetric(label: "Time", value: time)
        RunMetric(label: "Avg pace", value: pace, unit: "/km")
      }
    } else {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
          RunMetric(label: "Distance", value: distance, unit: "km").fixedSize(
            horizontal: true, vertical: false
          ).frame(maxWidth: .infinity, alignment: .leading)
          RunMetric(label: "Time", value: time).fixedSize(horizontal: true, vertical: false).frame(
            maxWidth: .infinity, alignment: .leading)
          RunMetric(label: "Avg pace", value: pace, unit: "/km").fixedSize(
            horizontal: true, vertical: false
          ).frame(maxWidth: .infinity, alignment: .leading)
        }
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
          RunMetric(label: "Distance", value: distance, unit: "km")
          RunMetric(label: "Time", value: time)
          RunMetric(label: "Avg pace", value: pace, unit: "/km")
        }
      }
    }
  }

  private func formattedTime(_ seconds: TimeInterval) -> String? {
    guard seconds.isFinite, seconds >= 0, seconds < Double(Int64.max) else { return nil }
    let duration = Duration.seconds(seconds.rounded())
    return duration.formatted(
      seconds >= 3_600 ? .time(pattern: .hourMinuteSecond) : .time(pattern: .minuteSecond))
  }

}
