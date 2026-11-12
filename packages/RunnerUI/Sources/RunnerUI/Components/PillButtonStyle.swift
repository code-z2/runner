import SwiftUI

public struct PillButtonStyle: ButtonStyle {

  public enum Variant: Sendable, CaseIterable {
    case primary
    case secondary
    case destructive
  }

  let variant: Variant

  @Environment(\.isEnabled) private var isEnabled

  public init(_ variant: Variant = .primary) {
    self.variant = variant
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .runnerText(.button)
      .foregroundStyle(foreground)
      .frame(maxWidth: .infinity, minHeight: Theme.Sizing.buttonHeight)
      .background(background, in: Capsule())
      .contentShape(Capsule())
      .opacity(opacity(pressed: configuration.isPressed))
      .scaleEffect(configuration.isPressed ? Theme.Interaction.pressedScale : 1)
      .animation(.snappy(duration: 0.18), value: configuration.isPressed)
  }

  private func opacity(pressed: Bool) -> Double {
    guard isEnabled else { return Theme.Interaction.disabledOpacity }
    return pressed ? Theme.Interaction.pressedOpacity : 1
  }

  private var background: Color {
    switch variant {
    case .primary: Theme.Colors.primary
    case .secondary: Theme.Colors.secondary
    case .destructive: Theme.Colors.destructive
    }
  }

  private var foreground: Color {
    switch variant {
    case .primary: Theme.Colors.primaryForeground
    case .secondary: Theme.Colors.secondaryForeground
    case .destructive: Theme.Colors.destructiveForeground
    }
  }
}

extension ButtonStyle where Self == PillButtonStyle {
  public static func pill(_ variant: PillButtonStyle.Variant = .primary) -> PillButtonStyle {
    PillButtonStyle(variant)
  }
}
