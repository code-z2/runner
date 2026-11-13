import RunnerUI
import SwiftUI

struct RunStartButton: View {

  let distance: RunDistance
  let onStart: ((Double?) -> Void)?

  @Environment(\.locale)
  private var locale

  @State
  private var taps = 0

  @ScaledMetric(relativeTo: .title)
  private var startDiameter = 210.0

  private var distanceLabel: String {
    switch distance {
    case .free: String(localized: "Free run")
    case .five: "5K"
    case .ten: "10K"
    case .custom(let measurement):
      measurement.formatted(.measurement(width: .abbreviated, usage: .asProvided).locale(locale))
    }
  }

  var body: some View {
    let diameter = min(startDiameter, 264)
    let rimInset = diameter * 0.042
    let faceInset = diameter * 0.089

    Button {
      taps += 1
      onStart?(distance.kilometers)
    } label: {
      VStack(spacing: Theme.Spacing.xs) {
        Text("Start")
          .runnerText(.title)
        Text(distanceLabel)
          .runnerText(.caption)
      }
      .foregroundStyle(Theme.Colors.primaryForeground)
      .frame(width: diameter, height: diameter)
      .background {
        ZStack {
          Circle().strokeBorder(
            Theme.Colors.primary.opacity(0.65), lineWidth: Theme.Sizing.hairline)
          Circle().inset(by: rimInset).fill(Theme.Colors.highlightSurface)
          Circle().inset(by: faceInset).fill(Theme.Colors.primary)
        }
      }
      .contentShape(Circle())
    }
    .buttonStyle(ReadyButtonStyle())
    .disabled(onStart == nil)
    .sensoryFeedback(.impact(weight: .medium), trigger: taps)
    .accessibilityLabel("Start run")
    .accessibilityValue(distanceLabel)
  }
}
