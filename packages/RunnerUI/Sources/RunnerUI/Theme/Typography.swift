import SwiftUI

extension Theme {
  public enum Typography {

    public enum Family: Sendable, Equatable {
      case system
      case serif
    }

    public struct Style: Sendable {
      public let family: Family
      public let size: CGFloat
      public let weight: Font.Weight
      public let italic: Bool
      public let monospacedDigits: Bool
      public let uppercase: Bool
      public let lineHeight: CGFloat
      public let tracking: CGFloat
      public let textStyle: Font.TextStyle

      public var font: Font {
        font(size: size)
      }

      public var lineSpacing: CGFloat {
        size * (lineHeight - 1)
      }

      public var italicized: Style {
        Style(
          family: family, size: size, weight: weight, italic: true,
          monospacedDigits: monospacedDigits, uppercase: uppercase,
          lineHeight: lineHeight, tracking: tracking, textStyle: textStyle)
      }

      func font(size: CGFloat) -> Font {
        let base: Font
        switch family {
        case .serif where RunnerFonts.register():
          base = .custom(
            italic ? RunnerFonts.serifItalic : RunnerFonts.serifRegular, fixedSize: size)
        case .serif:
          base =
            italic
            ? .system(size: size, design: .serif).italic() : .system(size: size, design: .serif)
        case .system:
          base =
            italic
            ? .system(size: size, weight: weight).italic() : .system(size: size, weight: weight)
        }
        return monospacedDigits ? base.monospacedDigit() : base
      }

      static func serif(
        _ size: CGFloat, lineHeight: CGFloat, textStyle: Font.TextStyle
      ) -> Style {
        Style(
          family: .serif, size: size, weight: .regular, italic: false,
          monospacedDigits: false, uppercase: false,
          lineHeight: lineHeight, tracking: 0, textStyle: textStyle)
      }

      static func system(
        _ size: CGFloat, _ weight: Font.Weight, trackingPercent: CGFloat = 0,
        monospacedDigits: Bool = false, uppercase: Bool = false,
        lineHeight: CGFloat = Primitive.LineHeight.normal, textStyle: Font.TextStyle
      ) -> Style {
        Style(
          family: .system, size: size, weight: weight, italic: false,
          monospacedDigits: monospacedDigits, uppercase: uppercase,
          lineHeight: lineHeight, tracking: size * trackingPercent / 100, textStyle: textStyle)
      }

      public static let countdown = serif(
        Primitive.FontSize.serifCountdown, lineHeight: Primitive.LineHeight.tight,
        textStyle: .largeTitle)
      public static let display = serif(
        Primitive.FontSize.serifDisplay, lineHeight: Primitive.LineHeight.tight,
        textStyle: .largeTitle)
      public static let titleLarge = serif(
        Primitive.FontSize.serifLarge, lineHeight: Primitive.LineHeight.tight,
        textStyle: .largeTitle)
      public static let title = serif(
        Primitive.FontSize.serifTitle, lineHeight: Primitive.LineHeight.snug,
        textStyle: .title)
      public static let titleSmall = serif(
        Primitive.FontSize.serifSmall, lineHeight: Primitive.LineHeight.snug,
        textStyle: .title3)

      public static let metricHero = system(
        Primitive.FontSize.metricHero, .bold, trackingPercent: -5, monospacedDigits: true,
        lineHeight: Primitive.LineHeight.tight, textStyle: .largeTitle)
      public static let metricLarge = system(
        Primitive.FontSize.metricLarge, .light, trackingPercent: -2, monospacedDigits: true,
        lineHeight: Primitive.LineHeight.tight, textStyle: .largeTitle)
      public static let metric = system(
        Primitive.FontSize.metric, .light, trackingPercent: -1, monospacedDigits: true,
        lineHeight: Primitive.LineHeight.tight, textStyle: .largeTitle)
      public static let stat = system(
        Primitive.FontSize.stat, .medium, monospacedDigits: true,
        lineHeight: Primitive.LineHeight.snug, textStyle: .title2)

      public static let statLight = system(
        Primitive.FontSize.stat, .regular, monospacedDigits: true,
        lineHeight: Primitive.LineHeight.snug, textStyle: .title2)

      public static let button = system(
        Primitive.FontSize.headline, .semibold, textStyle: .headline)
      public static let headline = system(
        Primitive.FontSize.headline, .medium, textStyle: .headline)
      public static let callout = system(
        Primitive.FontSize.callout, .medium, textStyle: .callout)
      public static let body = system(
        Primitive.FontSize.body, .regular, textStyle: .body)
      public static let bodyMedium = system(
        Primitive.FontSize.body, .medium, textStyle: .body)
      public static let subheadline = system(
        Primitive.FontSize.subheadline, .regular, textStyle: .subheadline)
      public static let subheadlineMedium = system(
        Primitive.FontSize.subheadline, .medium, textStyle: .subheadline)
      public static let footnote = system(
        Primitive.FontSize.footnote, .regular, textStyle: .footnote)
      public static let caption = system(
        Primitive.FontSize.caption, .regular, textStyle: .caption)
      public static let eyebrow = system(
        Primitive.FontSize.eyebrow, .medium, trackingPercent: 12, uppercase: true,
        textStyle: .caption2)
    }
  }
}

private struct RunnerTextStyle: ViewModifier {

  let style: Theme.Typography.Style

  @ScaledMetric
  private var scaledSize: CGFloat

  init(style: Theme.Typography.Style) {
    self.style = style
    _scaledSize = ScaledMetric(wrappedValue: style.size, relativeTo: style.textStyle)
  }

  func body(content: Content) -> some View {
    content
      .font(style.font(size: scaledSize))
      .tracking(scaledSize / style.size * style.tracking)
      .lineSpacing(scaledSize * (style.lineHeight - 1))
      .textCase(style.uppercase ? .uppercase : nil)
  }
}

extension View {
  public func runnerText(_ style: Theme.Typography.Style) -> some View {
    modifier(RunnerTextStyle(style: style))
  }
}
