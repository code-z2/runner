import RunnerUI
import SwiftUI

struct HomeTabBar: View {

  @Binding
  var selection: HomeTab

  let openPacePilot: () -> Void

  var body: some View {
    HStack(spacing: Theme.Spacing.md) {
      HStack(spacing: Theme.Spacing.xs) {
        HomeTabButton(title: "Run", symbol: "waveform.path", selected: selection == .run) {
          selection = .run
        }
        HomeTabButton(title: "Goals", symbol: "target", selected: selection == .goals) {
          selection = .goals
        }
      }
      .padding(Theme.Spacing.xs)
      .background(Theme.Colors.inverse, in: Capsule())

      Spacer(minLength: 0)

      HomeTabButton(
        title: "PacePilot", symbol: "figure.run", prominent: true, action: openPacePilot
      )
      .padding(Theme.Spacing.xs)
      .background(Theme.Colors.inverse, in: Circle())
    }
    .runnerShadow(Theme.Elevation.floating)
    .padding(.horizontal, Theme.Spacing.screenInset)
    .padding(.vertical, Theme.Spacing.xs)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Tabs")
  }
}
