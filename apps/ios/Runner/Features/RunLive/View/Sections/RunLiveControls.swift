import RunnerUI
import SwiftUI

struct RunLiveControls: View {

  let paused: Bool
  let canPause: Bool
  let canFinish: Bool
  let togglePause: () -> Void
  let finish: () -> Void

  @GestureState
  private var offset: CGFloat = 0

  @State
  private var confirmingFinish = false

  @State
  private var finishes = 0

  @Environment(\.layoutDirection)
  private var layoutDirection

  var body: some View {
    HStack(spacing: Theme.Spacing.sm) {
      Button(action: togglePause) {
        Image(systemName: paused ? "play.fill" : "pause.fill")
          .frame(width: Theme.Sizing.buttonHeight, height: Theme.Sizing.buttonHeight)
          .background(Theme.Colors.surfaceRaised, in: Circle())
      }
      .disabled(!canPause)
      .accessibilityLabel(paused ? "Resume run" : "Pause run")
      .sensoryFeedback(.impact(weight: .medium), trigger: paused)

      GeometryReader { geometry in
        let travel = max(0, geometry.size.width - Theme.Sizing.buttonHeight)
        let direction: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
        Button(action: { confirmingFinish = true }) {
          Capsule()
            .fill(Theme.Colors.surfaceRaised)
            .overlay {
              Text("Slide to finish")
                .runnerText(.footnote)
                .padding(.leading, Theme.Sizing.buttonHeight)
            }
            .overlay(alignment: .leading) {
              Image(systemName: "arrow.forward")
                .foregroundStyle(Theme.Colors.primaryForeground)
                .frame(width: Theme.Sizing.tapTargetMin, height: Theme.Sizing.tapTargetMin)
                .background(Theme.Colors.highlight, in: Circle())
                .padding(.leading, Theme.Spacing.xs)
                .offset(x: direction * min(offset, travel))
                .gesture(
                  DragGesture()
                    .updating($offset) { value, state, _ in
                      state = max(0, direction * value.translation.width)
                    }
                    .onEnded { value in
                      if travel > 0, direction * value.translation.width >= travel * 0.8 {
                        completeFinish()
                      }
                    }
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Finish run")
      }
      .frame(height: Theme.Sizing.buttonHeight)
      .disabled(!canFinish)
    }
    .buttonStyle(.plain)
    .confirmationDialog(
      "Finish this run?", isPresented: $confirmingFinish, titleVisibility: .visible
    ) {
      Button("Finish run", action: completeFinish)
      Button("Cancel", action: {})
    }
    .sensoryFeedback(.success, trigger: finishes)
  }

  private func completeFinish() {
    finishes += 1
    finish()
  }
}
