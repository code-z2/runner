import RunnerUI
import SwiftUI

struct RunBestTile: ViewModifier {

  func body(content: Content) -> some View {
    content
      .padding(Theme.Spacing.md)
      .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
  }
}
