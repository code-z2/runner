import RunnerUI
import SwiftUI

struct RunPersonalBests: View {

  let metrics: RunHistoryMetrics

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  @Environment(\.locale)
  private var locale

  var body: some View {
    let layout =
      dynamicType.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: Theme.Spacing.sm))
      : AnyLayout(HStackLayout(spacing: Theme.Spacing.sm))

    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      Text("Personal bests")
        .runnerText(.eyebrow)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
        .accessibilityAddTraits(.isHeader)
      layout {
        RunMetric(label: "5K", value: metrics.fastest(at: 5_000).flatMap(RunHistoryMetrics.time))
          .modifier(RunBestTile())
        RunMetric(label: "10K", value: metrics.fastest(at: 10_000).flatMap(RunHistoryMetrics.time))
          .modifier(RunBestTile())
        RunMetric(
          label: "Longest",
          value: metrics.longest?.formatted(.number.precision(.fractionLength(1)).locale(locale)),
          unit: "km"
        )
        .modifier(RunBestTile())
      }
    }
  }
}
