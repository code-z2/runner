import Foundation

struct RunWeather: Sendable {

  let temperature: Measurement<UnitTemperature>
  let condition: String
  let symbolName: String
}
