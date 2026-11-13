import Foundation

enum RunDistanceUnit: String, CaseIterable {
  case kilometers = "km"
  case miles = "mi"

  var unit: UnitLength { self == .kilometers ? .kilometers : .miles }
}
