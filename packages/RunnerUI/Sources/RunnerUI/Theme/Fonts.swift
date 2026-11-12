import CoreText
import Foundation

public enum RunnerFonts {

  public static let serifRegular = "InstrumentSerif-Regular"
  public static let serifItalic = "InstrumentSerif-Italic"

  @discardableResult
  public static func register() -> Bool {
    registered
  }

  private static let registered: Bool = [serifRegular, serifItalic].allSatisfy(registerFont)

  private static func registerFont(_ postScriptName: String) -> Bool {
    if isAvailable(postScriptName) {
      return true
    }
    guard let url = Bundle.module.url(forResource: postScriptName, withExtension: "ttf") else {
      return false
    }
    var error: Unmanaged<CFError>?
    let added = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    error?.release()
    return added || isAvailable(postScriptName)
  }

  static func isAvailable(_ postScriptName: String) -> Bool {
    let font = CTFontCreateWithName(postScriptName as CFString, 12, nil)
    return CTFontCopyPostScriptName(font) as String == postScriptName
  }
}
