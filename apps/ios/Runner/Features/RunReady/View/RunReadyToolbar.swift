import RunnerUI
import SwiftUI

struct RunReadyToolbar: ViewModifier {

  let visible: Bool
  let date: Date
  let showCommunity: () -> Void

  func body(content: Content) -> some View {
    if #available(iOS 27.2, *), visible {
      content
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleAlignment(.leading)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbar {
          ToolbarItem(placement: .title) { RunDateLabel(date: date) }
          ToolbarItem(placement: .topBarTrailing) {
            Button("Community", action: showCommunity)
              .buttonStyle(.pill(.secondary, compact: true))
          }
          .sharedBackgroundVisibility(.hidden)
        }
    } else {
      content.toolbarVisibility(.hidden, for: .navigationBar)
    }
  }
}
