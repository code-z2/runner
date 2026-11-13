import RunnerUI
import SwiftUI

struct RunMetric: View {

  let label: LocalizedStringKey
  let value: String?
  var unit: LocalizedStringKey?

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
      Text(label)
        .runnerText(.eyebrow)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
      HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
        Text(value ?? "—")
          .runnerText(.statLight)
        if value != nil, let unit {
          Text(unit)
            .runnerText(.caption)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

}
