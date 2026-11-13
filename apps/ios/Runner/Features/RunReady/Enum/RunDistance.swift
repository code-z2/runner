import Foundation

enum RunDistance: Equatable {

  case free
  case five
  case ten
  case custom(Measurement<UnitLength>)

  var kilometers: Double? {
    switch self {
    case .free: nil
    case .five: 5
    case .ten: 10
    case .custom(let distance): distance.converted(to: .kilometers).value
    }
  }
}
