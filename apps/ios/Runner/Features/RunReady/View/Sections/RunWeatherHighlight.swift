import RunnerUI
import SwiftUI

struct RunWeatherHighlight: View {

  /// Nil renders an invisible keeper with identical metrics, so the
  /// hero layout never shifts when the first fetch lands.
  let weather: RunWeather?

  @Environment(\.locale)
  private var locale

  var body: some View {
    HStack(spacing: Theme.Spacing.sm) {
      Image(systemName: weather?.symbolName ?? "cloud")
        .font(.callout)
        .accessibilityHidden(true)
      Text(highlightText)
        .runnerText(.titleSmall)
        .lineLimit(1)
    }
    .opacity(weather == nil ? 0 : 1)
    .accessibilityHidden(weather == nil)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }

  private var highlightText: String {
    guard let weather else { return "—" }
    return
      "\(weather.temperature.formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0))).locale(locale))) · \(weather.condition)"
  }

}
