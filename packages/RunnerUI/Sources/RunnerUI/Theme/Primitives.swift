import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

extension Color {
  init(rgb: UInt32) {
    self.init(
      .sRGB,
      red: Double((rgb >> 16) & 0xFF) / 255,
      green: Double((rgb >> 8) & 0xFF) / 255,
      blue: Double(rgb & 0xFF) / 255,
      opacity: 1
    )
  }

  init(light: UInt32, dark: UInt32) {
    #if canImport(UIKit)
      self.init(
        uiColor: UIColor { trait in
          trait.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    #else
      self.init(
        nsColor: NSColor(name: nil) { appearance in
          appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(rgb: dark) : NSColor(rgb: light)
        })
    #endif
  }
}

#if canImport(UIKit)
  extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
      self.init(
        red: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: 1
      )
    }
  }
#elseif canImport(AppKit)
  extension NSColor {
    fileprivate convenience init(rgb: UInt32) {
      self.init(
        srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: 1
      )
    }
  }
#endif

enum Primitive {

  enum Hex {
    static let ivory: UInt32 = 0xF3EDE3
    static let ivoryRaised: UInt32 = 0xFBF7EF
    static let sand: UInt32 = 0xEBE3D5
    static let sandDeep: UInt32 = 0xE1D7C6
    static let linen: UInt32 = 0xE6D7BC
    static let stone: UInt32 = 0xD6CBB8
    static let taupe: UInt32 = 0xA49A8B
    static let umber: UInt32 = 0x6D655A
    static let slate: UInt32 = 0x57554F
    static let ink: UInt32 = 0x1C1813
    static let bronze: UInt32 = 0x8E6B35
    static let bronzeText: UInt32 = 0x9B7F4F
    static let brandGold: UInt32 = 0xB8893F
    static let gold: UInt32 = 0xE2C690
    static let brick: UInt32 = 0xD4433A

    static let night: UInt32 = 0x0A0A0B
    static let nightSurface: UInt32 = 0x141416
    static let nightRaised: UInt32 = 0x1D1D20
    static let nightBorder: UInt32 = 0x2A2A2F
    static let chalk: UInt32 = 0xF4F1EA
    static let ash: UInt32 = 0x8E8B84
    static let ember: UInt32 = 0xFF5B4F
    static let goldShade: UInt32 = 0x2A2418
    static let goldInk: UInt32 = 0x17120A
    static let shadow: UInt32 = 0x1C1712
  }

  enum Space {
    static let none: CGFloat = 0
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let huge: CGFloat = 40
    static let giant: CGFloat = 48
  }

  enum Radius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
    static let xl: CGFloat = 28
    static let pill: CGFloat = 999
  }

  enum FontSize {
    static let eyebrow: CGFloat = 11
    static let caption: CGFloat = 12
    static let footnote: CGFloat = 13
    static let subheadline: CGFloat = 14
    static let body: CGFloat = 15
    static let callout: CGFloat = 16
    static let headline: CGFloat = 17
    static let serifSmall: CGFloat = 22
    static let serifTitle: CGFloat = 34
    static let serifLarge: CGFloat = 40
    static let serifDisplay: CGFloat = 48
    static let serifCountdown: CGFloat = 180
    static let stat: CGFloat = 28
    static let metric: CGFloat = 48
    static let metricLarge: CGFloat = 72
    static let metricHero: CGFloat = 120
  }

  enum LineHeight {
    static let tight: CGFloat = 1.0
    static let snug: CGFloat = 1.15
    static let normal: CGFloat = 1.35
  }

  enum Dimension {
    static let tapTargetMin: CGFloat = 44
    static let chipHeight: CGFloat = 33
    static let buttonHeight: CGFloat = 56
    static let tabBarHeight: CGFloat = 60
    static let iconSm: CGFloat = 18
    static let iconMd: CGFloat = 24
    static let iconLg: CGFloat = 28
    static let hairline: CGFloat = 1
    static let iconStroke: CGFloat = 1.8
  }
}
