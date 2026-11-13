import SwiftUI

extension Theme {
  public enum Colors {

    public static let background = Color(light: Primitive.Hex.ivory, dark: Primitive.Hex.night)
    public static let surface = Color(light: Primitive.Hex.sand, dark: Primitive.Hex.nightSurface)
    public static let surfaceRaised = Color(
      light: Primitive.Hex.ivoryRaised, dark: Primitive.Hex.nightRaised)
    public static let surfaceSunken = Color(
      light: Primitive.Hex.sandDeep, dark: Primitive.Hex.nightSurface)

    public static let foreground = Color(light: Primitive.Hex.ink, dark: Primitive.Hex.chalk)
    public static let foregroundSecondary = Color(
      light: Primitive.Hex.umber, dark: Primitive.Hex.ash)
    public static let foregroundTertiary = Color(
      light: Primitive.Hex.taupe, dark: Primitive.Hex.slate)

    public static let primary = Color(light: Primitive.Hex.bronze, dark: Primitive.Hex.gold)
    public static let actionText = Color(light: Primitive.Hex.bronzeText, dark: Primitive.Hex.gold)
    public static let primaryForeground = Color(
      light: Primitive.Hex.ivoryRaised, dark: Primitive.Hex.goldInk)

    public static let secondary = Color(
      light: Primitive.Hex.sandDeep, dark: Primitive.Hex.nightRaised)
    public static let secondaryForeground = Color(
      light: Primitive.Hex.ink, dark: Primitive.Hex.chalk)

    public static let inverse = Color(light: Primitive.Hex.ink, dark: Primitive.Hex.chalk)
    public static let inverseForeground = Color(
      light: Primitive.Hex.chalk, dark: Primitive.Hex.ink)

    public static let highlight = Color(rgb: Primitive.Hex.gold)
    public static let highlightSurface = Color(
      light: Primitive.Hex.linen, dark: Primitive.Hex.goldShade)
    public static let brandMark = Color(rgb: Primitive.Hex.brandGold)

    public static let border = Color(light: Primitive.Hex.stone, dark: Primitive.Hex.nightBorder)
    public static let icon = Color(light: Primitive.Hex.slate, dark: Primitive.Hex.ash)

    public static let destructive = Color(light: Primitive.Hex.brick, dark: Primitive.Hex.ember)
    public static let destructiveForeground = Color(rgb: Primitive.Hex.ivoryRaised)
    public static let live = Color(rgb: Primitive.Hex.ember)

    public static let shadow = Color(rgb: Primitive.Hex.shadow)

    public static let heroFade = LinearGradient(
      stops: [
        .init(color: Color(rgb: Primitive.Hex.ivory).opacity(0.55), location: 0),
        .init(color: Color(rgb: Primitive.Hex.ivory).opacity(0), location: 0.3),
        .init(color: Color(rgb: Primitive.Hex.ivory).opacity(0), location: 0.62),
        .init(color: Color(rgb: Primitive.Hex.ivory).opacity(0.85), location: 0.9),
        .init(color: Color(rgb: Primitive.Hex.ivory), location: 1),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  public enum Interaction {
    public static let pressedOpacity: Double = 0.85
    public static let pressedScale: CGFloat = 0.98
    public static let disabledOpacity: Double = 0.4
  }
}
