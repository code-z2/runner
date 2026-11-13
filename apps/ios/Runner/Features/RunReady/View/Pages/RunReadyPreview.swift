#if DEBUG
  import SwiftUI

  struct RunReadyPreview: View {

    enum Fixture: String, CaseIterable {
      case demo = "Demo"
      case worstCase = "Worst case"
      case empty = "Empty"
    }

    @State
    private var fixture: Fixture

    @State
    private var navigation = HomeNavigation()

    private let date = Date(timeIntervalSince1970: 1_794_225_600)
    private let recentID = UUID()
    private let olderID = UUID()

    init(fixture: Fixture = .demo) {
      _fixture = State(initialValue: fixture)
    }

    var body: some View {
      HomeView(
        run: RunViewModel(runs: runs),
        weatherModel: WeatherModel(weather: weather, fetch: { nil }),
        date: date,
        navigation: navigation
      )
      .environment(\.dynamicTypeSize, fixture == .worstCase ? .accessibility3 : .large)
      .safeAreaInset(edge: .bottom) {
        Picker("Preview data", selection: $fixture) {
          ForEach(Fixture.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding()
        .background(.regularMaterial)
      }
    }

    private var runs: [RunSummary] {
      switch fixture {
      case .demo:
        [.init(id: recentID, distanceMeters: 5_120, elapsed: 1_541, date: date)]
      case .worstCase:
        [
          .init(id: recentID, distanceMeters: 161_000, elapsed: 89_113, date: date),
          .init(
            id: olderID, distanceMeters: nil, elapsed: 2_400, date: date.addingTimeInterval(-86_400)
          ),
        ]
      case .empty:
        []
      }
    }

    private var weather: RunWeather? {
      switch fixture {
      case .demo:
        .init(
          temperature: .init(value: 80, unit: .fahrenheit), condition: "Partly cloudy",
          symbolName: "cloud.sun")
      case .worstCase:
        .init(
          temperature: .init(value: -12, unit: .celsius), condition: "Scattered thunderstorms",
          symbolName: "cloud.bolt.rain")
      case .empty:
        nil
      }
    }
  }
#endif
