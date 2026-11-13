import RunnerUI
import SwiftUI

struct ReadyButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? Theme.Interaction.pressedOpacity : 1)
  }
}
