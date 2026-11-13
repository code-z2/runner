import RunnerUI
import SwiftUI

struct HomeTabButton: View {

  let title: LocalizedStringKey
  let symbol: String
  var selected = false
  var prominent = false
  let action: () -> Void

  var body: some View {
    let height = Theme.Sizing.tabBarHeight - 2 * Theme.Spacing.xs
    Button(action: action) {
      VStack(spacing: Theme.Spacing.hair) {
        if prominent {
          PacePilotSymbol()
        } else {
          Image(systemName: symbol).font(.footnote)
          Text(title).runnerText(.caption)
        }
      }
      .padding(.horizontal, prominent ? 0 : Theme.Spacing.lg)
      .frame(
        minWidth: prominent ? height : Theme.Sizing.tabBarHeight + Theme.Spacing.xl,
        minHeight: height
      )
      .foregroundStyle(
        selected ? Theme.Colors.highlight : Theme.Colors.inverseForeground.opacity(0.62)
      )
      .background(
        selected ? Theme.Colors.inverseForeground.opacity(0.10) : .clear, in: Capsule()
      )
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(prominent ? "PacePilot, AI run coach" : title)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
