import RunnerUI
import SwiftUI

struct PacePilotOptInPage: View {

  @Binding
  var enabled: Bool

  @Environment(\.dismiss)
  private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
          PacePilotOptInHeader()
          VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Want a *coach* while you run?")
              .runnerText(.title)
              .accessibilityAddTraits(.isHeader)
            Text("PacePilot listens to your pace and steps, and speaks only when it helps.")
              .runnerText(.body)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
          }

          VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("•  Taps a 1–2 rhythm to settle your stride, then goes quiet")
            Text("•  Suggests a little more only when your runs show you can")
            Text("•  Anounces milestones by distance.")
          }
          .runnerText(.body)

          // No default haptic on Toggle: announce the change explicitly.
          Toggle(isOn: $enabled) {
            VStack(alignment: .leading, spacing: Theme.Spacing.hair) {
              Text("PacePilot").runnerText(.bodyMedium)
              Text(enabled ? "On during your runs" : "Off until you turn it on")
                .runnerText(.caption)
                .foregroundStyle(Theme.Colors.foregroundSecondary)
            }
          }
          .sensoryFeedback(.selection, trigger: enabled)
          .tint(Theme.Colors.primary)
          .padding(Theme.Spacing.md)
          .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .padding(.horizontal, Theme.Spacing.screenInset)
        .padding(.vertical, Theme.Spacing.sm)
      }
      .foregroundStyle(Theme.Colors.foreground)
      .background(Theme.Colors.background.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
        }
      }
    }
  }
}

#Preview("PacePilot opt-in") {
  @Previewable @State var enabled = false
  PacePilotOptInPage(enabled: $enabled)
}
