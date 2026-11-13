import RunnerUI
import SwiftUI

struct RunHistoryRow: View {

  let run: RunSummary

  @Environment(\.locale)
  private var locale

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  private var kilometers: Double? { RunHistoryMetrics.kilometers(run.distanceMeters) }

  var body: some View {
    let layout =
      dynamicType.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.sm))
      : AnyLayout(HStackLayout(alignment: .top))
    layout {
      VStack(alignment: .leading, spacing: Theme.Spacing.hair) {
        if let kilometers {
          Text("\(kilometers, format: .number.precision(.fractionLength(2)).locale(locale)) km")
            .runnerText(.bodyMedium)
        } else {
          Text("Distance unavailable").runnerText(.bodyMedium)
        }
        Text(run.date, format: .dateTime.weekday(.abbreviated).day())
          .runnerText(.caption)
          .foregroundStyle(Theme.Colors.foregroundSecondary)
      }
      if !dynamicType.isAccessibilitySize { Spacer(minLength: Theme.Spacing.sm) }
      VStack(
        alignment: dynamicType.isAccessibilitySize ? .leading : .trailing,
        spacing: Theme.Spacing.hair
      ) {
        Text(RunHistoryMetrics.time(run.elapsed) ?? "—").runnerText(.bodyMedium)
        if let kilometers, let pace = RunHistoryMetrics.time(run.elapsed / kilometers) {
          Text("\(pace) /km")
            .runnerText(.caption)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
        }
      }
    }
    .padding(.vertical, Theme.Spacing.md)
    .accessibilityElement(children: .combine)
  }
}
