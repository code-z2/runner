import SwiftUI

public struct PillButtonStyle: ButtonStyle {

  public enum Variant: Sendable, CaseIterable {
    case primary
    case secondary
    case destructive
  }

  let variant: Variant
  let compact: Bool

  @Environment(\.isEnabled) private var isEnabled

  public init(_ variant: Variant = .primary, compact: Bool = false) {
    self.variant = variant
    self.compact = compact
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .runnerText(compact ? .caption : .button)
      .foregroundStyle(foreground)
      .padding(.horizontal, compact ? Theme.Spacing.md : 0)
      .frame(
        maxWidth: compact ? nil : .infinity,
        minHeight: compact ? Theme.Sizing.chipHeight : Theme.Sizing.buttonHeight
      )
      .background(background, in: Capsule())
      .frame(minWidth: Theme.Sizing.tapTargetMin, minHeight: Theme.Sizing.tapTargetMin)
      .contentShape(Rectangle())
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
  public static func pill(
    _ variant: PillButtonStyle.Variant = .primary, compact: Bool = false
  ) -> PillButtonStyle {
    PillButtonStyle(variant, compact: compact)
  }
}
