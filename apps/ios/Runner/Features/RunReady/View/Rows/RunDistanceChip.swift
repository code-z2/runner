import RunnerUI
import SwiftUI

struct RunDistanceChip: View {

  let title: LocalizedStringKey
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .runnerText(.footnote)
        .padding(.horizontal, Theme.Spacing.md)
        .frame(minWidth: Theme.Sizing.tapTargetMin, minHeight: Theme.Sizing.chipHeight)
        .background(
          selected ? Theme.Colors.primary : Theme.Colors.secondary, in: Capsule()
        )
        .foregroundStyle(
          selected ? Theme.Colors.primaryForeground : Theme.Colors.foreground
        )
        .frame(minHeight: Theme.Sizing.tapTargetMin)
        .contentShape(Rectangle())
    }
    .buttonStyle(ReadyButtonStyle())
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
