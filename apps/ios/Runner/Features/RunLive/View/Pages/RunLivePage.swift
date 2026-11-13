import RunnerUI
import SwiftUI

struct RunLivePage: View {

  let goalKilometers: Double?
  let pacePilotEnabled: Bool
  var previewDistance: Double?
  var finish: (TimeInterval) -> Void = { _ in }

  @State
  private var segmentStart = Date.now

  @State
  private var accumulated: TimeInterval = 0

  @State
  private var paused = false

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        HStack {
          Label(paused ? "Paused" : "Recording", systemImage: "circle.fill")
            .runnerText(.caption)
            .foregroundStyle(paused ? Theme.Colors.foregroundSecondary : Theme.Colors.live)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Colors.surfaceRaised, in: Capsule())
          Spacer()
          if let goalKilometers {
            Text("\(goalKilometers.formatted())K goal")
              .runnerText(.caption)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
          }
        }

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text("Distance").runnerText(.eyebrow)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text((previewDistance ?? 0).formatted(.number.precision(.fractionLength(2))))
              .runnerText(.metricHero)
              .lineLimit(1)
              .minimumScaleFactor(0.35)
            Text("km").runnerText(.statLight)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
          }
          if let goalKilometers, goalKilometers > 0 {
            ProgressView(value: min(previewDistance ?? 0, goalKilometers), total: goalKilometers)
              .tint(Theme.Colors.highlight)
            HStack {
              Text(
                "\((previewDistance ?? 0).formatted(.number.precision(.fractionLength(2)))) of \(goalKilometers.formatted(.number.precision(.fractionLength(2)))) km"
              )
              Spacer()
              Text(
                "\(max(0, (goalKilometers - (previewDistance ?? 0)) * 1_000).formatted(.number.precision(.fractionLength(0)))) m to go"
              )
              .foregroundStyle(Theme.Colors.highlight)
            }
            .runnerText(.caption)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          }
        }

        Divider()

        LazyVGrid(
          columns: Array(
            repeating: GridItem(.flexible(), alignment: .leading),
            count: dynamicType.isAccessibilitySize ? 1 : 2),
          alignment: .leading, spacing: Theme.Spacing.md
        ) {
          TimelineView(.periodic(from: segmentStart, by: 1)) { context in
            let elapsed =
              accumulated + (paused ? 0 : max(0, context.date.timeIntervalSince(segmentStart)))
            RunMetric(
              label: "Time",
              value: previewDistance == nil
                ? Duration.seconds(elapsed.rounded(.down)).formatted(.time(pattern: .minuteSecond))
                : "24:18")
          }
          RunMetric(label: "Pace", value: previewDistance == nil ? nil : "5:02", unit: "/km")
          RunMetric(label: "Avg pace", value: previewDistance == nil ? nil : "5:03", unit: "/km")
          RunMetric(label: "Cadence", value: previewDistance == nil ? nil : "172", unit: "spm")
          RunMetric(label: "Heart rate", value: nil, unit: "bpm")
          RunMetric(label: "Runners crossed", value: previewDistance == nil ? "0" : "3")
        }

        if pacePilotEnabled { PacePilotStatusCard() }
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.sm)
    }
    .safeAreaInset(edge: .bottom) {
      RunLiveControls(paused: paused, togglePause: togglePause) {
        finish(accumulated + (paused ? 0 : max(0, Date.now.timeIntervalSince(segmentStart))))
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.sm)
      .background(Theme.Colors.background)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
    .environment(\.colorScheme, .dark)
    .toolbarVisibility(.hidden, for: .navigationBar)
    .statusBarHidden(false)
  }

  private func togglePause() {
    if paused {
      segmentStart = .now
    } else {
      accumulated += max(0, Date.now.timeIntervalSince(segmentStart))
    }
    paused.toggle()
  }
}

#Preview("Live · PacePilot on") {
  RunLivePage(goalKilometers: 5, pacePilotEnabled: true, previewDistance: 4.82)
}
