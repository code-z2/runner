import SwiftUI

extension Theme {
  public enum Elevation {
    public struct Layer: Sendable {
      public let opacity: Double
      public let radius: CGFloat
      public let x: CGFloat
      public let y: CGFloat

      public init(opacity: Double, radius: CGFloat, x: CGFloat, y: CGFloat) {
        self.opacity = opacity
        self.radius = radius
        self.x = x
        self.y = y
      }
    }

    public static let none: [Layer] = []

    public static let card: [Layer] = [
      Layer(opacity: 0.06, radius: 1, x: 0, y: 1),
      Layer(opacity: 0.08, radius: 8, x: 0, y: 4),
    ]

    public static let floating: [Layer] = [
      Layer(opacity: 0.18, radius: 12, x: 0, y: 8)
    ]
  }
}

private struct RunnerElevation: ViewModifier {
  let layers: [Theme.Elevation.Layer]
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    if scheme == .dark {
      content
    } else {
      layers.reduce(AnyView(content)) { view, layer in
        AnyView(
          view.shadow(
            color: Theme.Colors.shadow.opacity(layer.opacity),
            radius: layer.radius, x: layer.x, y: layer.y))
      }
    }
  }
}

extension View {
  public func runnerShadow(_ elevation: [Theme.Elevation.Layer]) -> some View {
    modifier(RunnerElevation(layers: elevation))
  }
}
