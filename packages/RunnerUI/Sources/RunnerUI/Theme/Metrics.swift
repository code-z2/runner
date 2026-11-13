import CoreGraphics

extension Theme {
  public enum Spacing {
    public static let none = Primitive.Space.none
    public static let hair = Primitive.Space.xxs
    public static let xs = Primitive.Space.xs
    public static let sm = Primitive.Space.sm
    public static let md = Primitive.Space.md
    public static let lg = Primitive.Space.lg
    public static let xl = Primitive.Space.xl
    public static let xxl = Primitive.Space.xxl
    public static let section = Primitive.Space.xxxl
    public static let screenInset = Primitive.Space.xl
    public static let screenTop = Primitive.Space.giant
  }

  public enum Radius {
    public static let xs = Primitive.Radius.xs
    public static let sm = Primitive.Radius.sm
    public static let card = Primitive.Radius.md
    public static let sheet = Primitive.Radius.lg
    public static let hero = Primitive.Radius.xl
    public static let pill = Primitive.Radius.pill
  }

  public enum Sizing {
    public static let countdownDiameter: CGFloat = 280
    public static let tapTargetMin = Primitive.Dimension.tapTargetMin
    public static let chipHeight = Primitive.Dimension.chipHeight
    public static let buttonHeight = Primitive.Dimension.buttonHeight
    public static let tabBarHeight = Primitive.Dimension.tabBarHeight
    public static let iconSm = Primitive.Dimension.iconSm
    public static let iconMd = Primitive.Dimension.iconMd
    public static let iconLg = Primitive.Dimension.iconLg
    public static let hairline = Primitive.Dimension.hairline
    public static let iconStroke = Primitive.Dimension.iconStroke
  }
}
