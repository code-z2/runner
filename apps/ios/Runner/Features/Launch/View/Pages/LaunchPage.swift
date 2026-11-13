import RunnerUI
import SwiftUI

struct LaunchPage: View {

  /// Must match LaunchScreen.storyboard's image view exactly (size and
  /// centering). Both size the wordmark to 170/393 of the full screen
  /// width and pin it to the screen center with the same ivory
  /// background — the handoff stays seamless only while both frames are
  /// pixel-identical, so there is no entrance animation by design. Keep
  /// the storyboard multiplier (0.43257) and this fraction in sync.
  private let logoWidthFraction: Double = 170 / 393

  var body: some View {
    IjeWordmark()
      .containerRelativeFrame(.horizontal) { width, _ in width * logoWidthFraction }
      // Full-window centering, not safe-area centering: the launch
      // storyboard pins to the view's geometric center, so this must too —
      // otherwise the mark jumps ~12pt when the status bar appears.
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea()
      .background(Theme.Colors.background.ignoresSafeArea())
  }
}

#if DEBUG
  #Preview("Launch") {
    LaunchPage()
  }
#endif
