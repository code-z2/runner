import Foundation

enum DistanceUnit: String, CaseIterable {
  case kilometers = "km"
  case miles = "mi"

  var unit: UnitLength { self == .kilometers ? .kilometers : .miles }
}
