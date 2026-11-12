import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

extension Theme {
  public enum Brand {

    public static let name = "Ije"

    public enum Asset: String, CaseIterable, Sendable {
      case wordmark = "IjeWordmark"
      case wordmarkLight = "IjeWordmarkLight"
      case mark = "IjeMark"
    }

    public static func image(_ asset: Asset) -> Image {
      #if canImport(UIKit)
        if let image = UIImage(named: asset.rawValue, in: .module, with: nil) {
          return Image(uiImage: image)
        }
      #elseif canImport(AppKit)
        if let image = Bundle.module.image(forResource: asset.rawValue) {
          return Image(nsImage: image)
        }
      #endif
      return Image(systemName: "figure.run")
    }

    static func url(_ asset: Asset) -> URL? {
      Bundle.module.url(forResource: asset.rawValue, withExtension: "png")
    }
  }
}

public struct IjeWordmark: View {

  @Environment(\.colorScheme) private var scheme

  public init() {}

  public var body: some View {
    Theme.Brand.image(scheme == .dark ? .wordmarkLight : .wordmark)
      .resizable()
      .scaledToFit()
      .accessibilityLabel(Theme.Brand.name)
  }
}
