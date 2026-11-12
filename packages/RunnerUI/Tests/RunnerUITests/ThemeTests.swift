import SwiftUI
import Testing

@testable import RunnerUI

struct PaletteTests {

  @Test
  func lightPaletteMatchesFigma() {
    #expect(Primitive.Hex.ivory == 0xF3EDE3)
    #expect(Primitive.Hex.ink == 0x1C1813)
    #expect(Primitive.Hex.umber == 0x6D655A)
    #expect(Primitive.Hex.bronze == 0x8E6B35)
    #expect(Primitive.Hex.sandDeep == 0xE1D7C6)
    #expect(Primitive.Hex.ivoryRaised == 0xFBF7EF)
    #expect(Primitive.Hex.brick == 0xD4433A)
  }

  @Test
  func darkPaletteMatchesFigma() {
    #expect(Primitive.Hex.night == 0x0A0A0B)
    #expect(Primitive.Hex.nightRaised == 0x1D1D20)
    #expect(Primitive.Hex.chalk == 0xF4F1EA)
    #expect(Primitive.Hex.ash == 0x8E8B84)
    #expect(Primitive.Hex.gold == 0xE2C690)
    #expect(Primitive.Hex.ember == 0xFF5B4F)
  }
}

struct TypographyTests {

  typealias Style = Theme.Typography.Style

  @Test
  func headingsUseTheSerif() {
    for style in [Style.countdown, .display, .titleLarge, .title, .titleSmall] {
      #expect(style.family == .serif)
      #expect(style.italic == false)
    }
  }

  @Test
  func bodyStylesUseTheSystemFont() {
    for style in [Style.button, .headline, .body, .subheadline, .footnote, .caption, .eyebrow] {
      #expect(style.family == .system)
    }
  }

  @Test
  func trackingFollowsFigmaPercentages() {
    #expect(abs(Style.eyebrow.tracking - 1.32) < 0.0001)
    #expect(abs(Style.metricHero.tracking - -6) < 0.0001)
    #expect(abs(Style.metricLarge.tracking - -1.44) < 0.0001)
    #expect(Style.body.tracking == 0)
  }

  @Test
  func sizesMatchFigma() {
    #expect(Style.countdown.size == 180)
    #expect(Style.title.size == 34)
    #expect(Style.button.size == 17)
    #expect(Style.button.weight == .semibold)
    #expect(Style.stat.size == 28)
    #expect(Style.eyebrow.size == 11)
    #expect(Style.eyebrow.uppercase)
  }

  @Test
  func metricsKeepDigitsSteady() {
    for style in [Style.metricHero, .metricLarge, .metric, .stat] {
      #expect(style.monospacedDigits)
    }
  }

  @Test
  func italicizedOnlyChangesSlant() {
    let italic = Style.title.italicized
    #expect(italic.italic)
    #expect(italic.family == Style.title.family)
    #expect(italic.size == Style.title.size)
    #expect(italic.tracking == Style.title.tracking)
  }

  @Test
  func lineSpacingComesFromLineHeight() {
    #expect(abs(Style.body.lineSpacing - 15 * 0.35) < 0.0001)
    #expect(Style.countdown.lineSpacing == 0)
  }
}

struct FontTests {

  @Test
  func serifFontsRegister() {
    #expect(RunnerFonts.register())
    #expect(RunnerFonts.isAvailable(RunnerFonts.serifRegular))
    #expect(RunnerFonts.isAvailable(RunnerFonts.serifItalic))
  }

  @Test
  func registeringTwiceIsSafe() {
    #expect(RunnerFonts.register())
    #expect(RunnerFonts.register())
  }
}

struct BrandTests {

  @Test(arguments: Theme.Brand.Asset.allCases)
  func brandImagesShip(asset: Theme.Brand.Asset) {
    #expect(Theme.Brand.url(asset) != nil)
  }
}
