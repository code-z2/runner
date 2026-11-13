import RunnerUI
import SwiftUI

struct RunCountdownPage: View {

  let pacePilotEnabled: Bool
  var onCompletion: (() -> Void)?

  @State
  private var count = 3

  var body: some View {
    VStack(spacing: Theme.Spacing.xxl) {
      Text(count.formatted())
        .runnerText(.countdown)
        .sensoryFeedback(.impact(weight: .light), trigger: count)
        .foregroundStyle(Theme.Colors.highlight)
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .padding(Theme.Spacing.lg)
        .frame(width: Theme.Sizing.countdownDiameter, height: Theme.Sizing.countdownDiameter)
        .background(Theme.Colors.highlightSurface, in: Circle())
        .overlay {
          Circle().strokeBorder(
            Theme.Colors.highlight.opacity(0.55), lineWidth: Theme.Sizing.hairline)
        }
        .accessibilityLabel(Text("Countdown"))
        .accessibilityValue(Text(count.formatted()))
      Text("Get *set*")
        .runnerText(.title)
      Text(pacePilotEnabled ? "PacePilot is turned on" : "PacePilot is turned off")
        .runnerText(.footnote)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
        .multilineTextAlignment(.center)
    }
    .padding(Theme.Spacing.screenInset)
    .padding(.bottom, Theme.Spacing.section)
    .foregroundStyle(Theme.Colors.foreground)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background.ignoresSafeArea())
    .environment(\.colorScheme, .dark)
    .toolbarVisibility(.hidden, for: .navigationBar)
    .task {
      guard let onCompletion else { return }
      do {
        while count > 1 {
          try await Task.sleep(for: .seconds(1))
          count -= 1
        }
        try await Task.sleep(for: .seconds(1))
        onCompletion()
      } catch {
        return
      }
    }
  }
}

#Preview("PacePilot off") {
  RunCountdownPage(pacePilotEnabled: false)
}

#Preview("PacePilot on") {
  RunCountdownPage(pacePilotEnabled: true)
}
