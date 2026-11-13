import RunnerUI
import SwiftUI

struct PacePilotOptInHeader: View {

  var body: some View {
    VStack(spacing: Theme.Spacing.md) {
      Text("PacePilot").runnerText(.eyebrow)
      HStack(spacing: Theme.Spacing.sm) {
        ForEach(0..<4) { beat in
          Circle()
            .fill(Theme.Colors.primary.opacity(beat == 0 ? 1 : 0.45))
            .frame(
              width: beat == 0 ? Theme.Spacing.md : Theme.Spacing.xs,
              height: beat == 0 ? Theme.Spacing.md : Theme.Spacing.xs)
        }
      }
      .accessibilityHidden(true)
      Text("1 · 2 · 1 · 2").runnerText(.eyebrow)
    }
    .foregroundStyle(Theme.Colors.foregroundSecondary)
    .padding(Theme.Spacing.xxl)
    .frame(maxWidth: .infinity)
    .background(
      Theme.Colors.highlightSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.sheet))
  }
}
