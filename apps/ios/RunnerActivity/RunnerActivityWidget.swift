import ActivityKit
import RunnerUI
import SwiftUI
import WidgetKit

@main
struct RunnerActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RunActivityAttributes.self) { context in
      RunActivityLockScreen(state: context.state)
        .padding(Theme.Spacing.lg)
        .foregroundStyle(Theme.Colors.foreground)
        .activityBackgroundTint(Theme.Colors.background)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label("Ije", systemImage: "figure.run").runnerText(.bodyMedium)
        }
        DynamicIslandExpandedRegion(.trailing) {
          liveTimer(state: context.state).monospacedDigit()
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 0) {
            Spacer(minLength: 0)
            RunActivityMetrics(state: context.state)
          }
          .frame(maxHeight: .infinity)
        }
      } compactLeading: {
        Image(systemName: context.state.runningSince == nil ? "pause.fill" : "figure.run")
      } compactTrailing: {
        liveTimer(state: context.state).monospacedDigit().frame(maxWidth: 54)
      } minimal: {
        Image(systemName: context.state.runningSince == nil ? "pause.fill" : "figure.run")
      }
    }
    .supplementalActivityFamilies([.small])
  }
}

/// Lock Screen presentation. Adapts to the small family for the watchOS
/// Smart Stack; every other family gets the full three-column layout.
private struct RunActivityLockScreen: View {
  let state: RunActivityAttributes.ContentState

  @Environment(\.activityFamily) private var family

  var body: some View {
    if family == .small {
      VStack(alignment: .leading, spacing: 2) {
        statusRow
        liveTimer(state: state)
          .runnerText(.statLight)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(runSummaryLine(state: state))
          .runnerText(.caption)
          .foregroundStyle(Theme.Colors.foregroundSecondary)
          .lineLimit(1)
      }
    } else {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        HStack {
          Text("Ije").runnerText(.titleSmall)
          Spacer()
          statusText
        }
        RunActivityMetrics(state: state)
      }
    }
  }

  private var statusRow: some View {
    HStack {
      Text("Ije").runnerText(.caption)
      Spacer()
      statusText
    }
    .foregroundStyle(Theme.Colors.foregroundSecondary)
  }

  private var statusText: some View {
    Text(state.runningSince == nil ? "Paused" : "Recording")
      .runnerText(.caption)
  }
}

/// Pace · Time · Distance, each a big number over a light label.
private struct RunActivityMetrics: View {
  let state: RunActivityAttributes.ContentState

  var body: some View {
    HStack(spacing: 0) {
      metricColumn(value: paceValue, label: "Avg Pace")
      metricColumn(value: liveTimer(state: state), label: "Time")
      metricColumn(value: distanceValue, label: "Distance")
    }
  }

  private var paceValue: some View {
    Group {
      if let pace = runPaceText(state: state) {
        Text(pace)
      } else {
        Text("—")
      }
    }
  }

  private var distanceValue: some View {
    Group {
      if let distance = runDistanceText(state: state) {
        Text(distance)
      } else {
        Text("—")
      }
    }
  }

  private func metricColumn(value: some View, label: LocalizedStringKey) -> some View {
    VStack(spacing: Theme.Spacing.hair) {
      value
        .runnerText(.statLight)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.6)

      Text(label)
        .runnerText(.caption)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
  }
}

private func runPaceText(state: RunActivityAttributes.ContentState) -> String? {
  guard
    let pace = state.averagePace, pace.isFinite, pace >= 0,
    pace < Double(Int64.max)
  else { return nil }
  let rounded = pace.rounded()
  if rounded >= 3_600 {
    return Duration.seconds(rounded).formatted(.time(pattern: .hourMinuteSecond))
  }
  return Duration.seconds(rounded).formatted(.time(pattern: .minuteSecond))
}

private func runDistanceText(state: RunActivityAttributes.ContentState) -> String? {
  guard let meters = state.distanceMeters else { return nil }
  return (meters / 1_000).formatted(.number.precision(.fractionLength(1)))
}

private func liveTimer(state: RunActivityAttributes.ContentState) -> Text {
  if let runningSince = state.runningSince {
    Text(timerInterval: runningSince...Date.distantFuture, countsDown: false, showsHours: false)
  } else {
    Text(Duration.seconds(state.elapsed.rounded(.down)), format: .time(pattern: .minuteSecond))
  }
}

private func runSummaryLine(state: RunActivityAttributes.ContentState) -> String {
  switch (runDistanceText(state: state), runPaceText(state: state)) {
  case (let distance?, let pace?): return "\(distance) km · \(pace) /km"
  case (let distance?, nil): return "\(distance) km"
  case (nil, let pace?): return "\(pace) /km"
  default: return "—"
  }
}

#if DEBUG
  #Preview("Lock Screen", as: .content, using: RunActivityAttributes()) {
    RunnerActivityWidget()
  } contentStates: {
    RunActivityAttributes.ContentState(
      elapsed: 304, runningSince: .now.addingTimeInterval(-304), distanceMeters: 1_040,
      averagePace: 292)
    RunActivityAttributes.ContentState(
      elapsed: 304, runningSince: nil, distanceMeters: 1_040, averagePace: 292)
  }

  #Preview("Dynamic Island", as: .dynamicIsland(.compact), using: RunActivityAttributes()) {
    RunnerActivityWidget()
  } contentStates: {
    RunActivityAttributes.ContentState(
      elapsed: 304, runningSince: .now.addingTimeInterval(-304), distanceMeters: 1_040,
      averagePace: 292)
    RunActivityAttributes.ContentState(
      elapsed: 304, runningSince: nil, distanceMeters: 1_040, averagePace: 292)
  }
#endif
