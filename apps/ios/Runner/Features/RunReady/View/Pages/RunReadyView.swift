import RunnerUI
import SwiftUI

struct RunReadyView: View {

  let viewModel: RunViewModel
  var weather: RunWeather?
  var date: Date = .now
  var onStart: ((Double?) -> Void)?
  let open: (HomeDestination) -> Void

  @State
  private var distance = RunDistance.free

  @State
  private var customDistance: Measurement<UnitLength>?

  @State
  private var showingDistance = false

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  private var usesNativeHeader: Bool {
    if #available(iOS 27.2, *) { return !dynamicType.isAccessibilitySize }
    return false
  }

  var body: some View {
    ScrollView {
      VStack(spacing: Theme.Spacing.md) {
        RunReadyHero(
          weather: weather, date: date, usesNativeHeader: usesNativeHeader,
          distance: distance, onStart: onStart, showCommunity: { open(.community) })
        RunDistanceOptions(
          selection: distance, select: { distance = $0 },
          showCustom: {
            showingDistance = true
          })
        if let lastRun = viewModel.runs.first {
          LastRunCard(run: lastRun, showHistory: { open(.history) })
        } else {
          Text(viewModel.historyUnavailable ? "Run history is unavailable" : "No activity yet")
            .runnerText(.titleSmall)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
            .frame(minHeight: Theme.Spacing.screenTop)
        }
      }
      .padding(.bottom, Theme.Spacing.lg)
    }
    .background(alignment: .top) {
      RunHeroBackdrop().ignoresSafeArea(.container, edges: .top)
    }
    .background(Theme.Colors.background.ignoresSafeArea())
    .foregroundStyle(Theme.Colors.foreground)
    .modifier(RunReadyToolbar(visible: usesNativeHeader, date: date) { open(.community) })
    .sheet(isPresented: $showingDistance) {
      RunDistanceSheet(selection: customDistance) { selection in
        customDistance = selection
        distance = .custom(selection)
      }
    }
  }

}

#if DEBUG
  #Preview("Ready layout checks") {
    RunReadyPreview()
  }

  #Preview("Ready worst case") {
    RunReadyPreview(fixture: .worstCase)
  }

  #Preview("Ready empty") {
    RunReadyPreview(fixture: .empty)
  }
#endif
