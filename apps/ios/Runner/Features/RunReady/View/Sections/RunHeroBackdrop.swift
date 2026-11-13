import RunnerUI
import SwiftUI

struct RunHeroBackdrop: View {

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  private let photoHeight: CGFloat = 422

  var body: some View {
    GeometryReader { geometry in
      Image(.dawnRunner)
        .resizable()
        .scaledToFill()
        .frame(width: geometry.size.width, height: photoHeight, alignment: .bottom)
        .clipped()
        .overlay {
          LinearGradient(
            stops: [
              .init(color: Theme.Colors.background.opacity(0.72), location: 0),
              .init(color: Theme.Colors.background.opacity(0.55), location: 0.18),
              .init(color: Theme.Colors.background.opacity(0.18), location: 0.36),
              .init(color: .clear, location: 0.53),
              .init(color: .clear, location: 0.62),
              .init(color: Theme.Colors.background.opacity(0.85), location: 0.9),
              .init(color: Theme.Colors.background, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        }
        .opacity(dynamicType.isAccessibilitySize ? 0.22 : 1)
    }
    .accessibilityHidden(true)
    .allowsHitTesting(false)
  }
}
