import RunnerUI
import SwiftUI

struct RunReadyHero: View {

  let weather: RunWeather?
  let date: Date
  let usesNativeHeader: Bool
  let distance: RunDistance
  let onStart: ((Double?) -> Void)?
  let showCommunity: () -> Void

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  private let startTopInset: CGFloat = 226

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
      if !usesNativeHeader {
        let layout =
          dynamicType.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.sm))
          : AnyLayout(HStackLayout(alignment: .top))
        layout {
          VStack(alignment: .leading, spacing: Theme.Spacing.hair) {
            RunDateLabel(date: date)
            RunWeatherHighlight(weather: weather)
          }
          if !dynamicType.isAccessibilitySize { Spacer(minLength: Theme.Spacing.xs) }
          Button("Community", action: showCommunity)
            .buttonStyle(.pill(.secondary, compact: true))
        }
      } else {
        RunWeatherHighlight(weather: weather)
      }
      Link(
        "Apple Weather",
        destination: URL(
          string: "https://developer.apple.com/weatherkit/data-source-attribution/")!
      )
      .runnerText(.caption)
      .foregroundStyle(Theme.Colors.foregroundSecondary)
      .opacity(weather == nil ? 0 : 1)
      .disabled(weather == nil)
      .accessibilityHidden(weather == nil)
      RunStartButton(distance: distance, onStart: onStart)
        .frame(maxWidth: .infinity)
        .padding(
          .top,
          dynamicType.isAccessibilitySize
            ? Theme.Spacing.lg
            : startTopInset - (usesNativeHeader ? Theme.Spacing.section + Theme.Spacing.sm : 0))
    }
    .padding(.horizontal, Theme.Spacing.screenInset)
    .padding(.top, Theme.Spacing.sm)
  }
}
