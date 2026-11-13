import RunnerPacePilot
import RunnerUI
import SwiftUI

struct PacePilotStatusCard: View {

  var state: CoachState = .idle

  private var phase: LocalizedStringKey {
    switch state {
    case .idle: "On"
    case .warmUp: "Warm-up"
    case .steady: "Steady"
    case .accelerating: "Accelerating"
    case .interval: "Interval"
    case .recovery: "Recovery"
    case .cooldown: "Cooldown"
    }
  }

  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      Text("PacePilot · On")
        .runnerText(.eyebrow)
        .foregroundStyle(Theme.Colors.highlight)

      if state != .idle { Text(phase).runnerText(.caption) }

      PhaseAnimator(reduceMotion ? [0] : [0, 1, 2, 3]) { phase in
        HStack(spacing: Theme.Spacing.sm) {
          ForEach(0..<4) { index in
            Circle()
              .fill(Theme.Colors.highlight)
              .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
              .opacity(index == phase ? 1 : 0.3)
              .scaleEffect(!reduceMotion && index == phase ? 1.25 : 1)
          }
        }
      } animation: { _ in
        .easeInOut(duration: 0.25)
      }
      .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Theme.Spacing.lg)
    .background(
      Theme.Colors.highlightSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
  }
}
