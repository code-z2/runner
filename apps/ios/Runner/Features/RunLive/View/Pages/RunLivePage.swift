import RunnerUI
import SwiftUI

struct RunLivePage: View {

  let goalKilometers: Double?
  let pacePilotEnabled: Bool
  var previewDistance: Double?
  var model: RunLiveViewModel?
  var onStartFailure: () -> Void = {}
  var onFinish: (RunSummary) async -> Void = { _ in }

  @State
  private var error: LocalizedStringResource?

  @State
  private var startFailed = false

  private var paused: Bool { model?.state == .paused }
  private var distance: Double? { previewDistance ?? model?.distanceMeters.map { $0 / 1_000 } }
  private var canPause: Bool { model?.state == .active || paused }
  private var canFinish: Bool { canPause || model?.state == .finished }
  private var status: LocalizedStringKey {
    switch model?.state {
    case .idle: "Starting"
    case .paused: "Paused"
    case .finished: "Finished"
    default: "Recording"
    }
  }

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        HStack {
          Label(status, systemImage: "circle.fill")
            .runnerText(.caption)
            .foregroundStyle(paused ? Theme.Colors.foregroundSecondary : Theme.Colors.live)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Colors.surfaceRaised, in: Capsule())
          Spacer()
          if let goalKilometers {
            Text("\(goalKilometers.formatted())K goal")
              .runnerText(.caption)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
          }
        }

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text("Distance").runnerText(.eyebrow)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text(distance?.formatted(.number.precision(.fractionLength(2))) ?? "—")
              .runnerText(.metricHero)
              .lineLimit(1)
              .minimumScaleFactor(0.35)
            Text("km").runnerText(.statLight)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
          }
          if let goalKilometers, goalKilometers > 0, let distance {
            ProgressView(value: min(distance, goalKilometers), total: goalKilometers)
              .tint(Theme.Colors.highlight)
            HStack {
              Text(
                "\((distance).formatted(.number.precision(.fractionLength(2)))) of \(goalKilometers.formatted(.number.precision(.fractionLength(2)))) km"
              )
              Spacer()
              Text(
                "\(max(0, (goalKilometers - (distance)) * 1_000).formatted(.number.precision(.fractionLength(0)))) m to go"
              )
              .foregroundStyle(Theme.Colors.highlight)
            }
            .runnerText(.caption)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          }
        }

        Divider()

        LazyVGrid(
          columns: Array(
            repeating: GridItem(.flexible(), alignment: .leading),
            count: dynamicType.isAccessibilitySize ? 1 : 2),
          alignment: .leading, spacing: Theme.Spacing.md
        ) {
          RunMetric(
            label: "Time",
            value: previewDistance == nil
              ? RunHistoryMetrics.time(model?.elapsed ?? 0)
              : "24:18")
          RunMetric(
            label: "Pace",
            value: previewDistance == nil
              ? model?.pace.flatMap(RunHistoryMetrics.paceTime) : "5:02",
            unit: "/km")
          RunMetric(
            label: "Avg pace",
            value: previewDistance == nil
              ? model?.averagePace.flatMap(RunHistoryMetrics.paceMinutes) : "5", unit: "min/km")
          RunMetric(
            label: "Cadence",
            value: previewDistance == nil
              ? model?.cadenceStepsPerMinute?.formatted(.number.precision(.fractionLength(0)))
              : "172", unit: "spm")
          RunMetric(
            label: "Heart rate",
            value: model?.heartRate?.formatted(.number.precision(.fractionLength(0))), unit: "bpm")
          RunMetric(label: "Runners crossed", value: previewDistance == nil ? "0" : "3")
        }

        if pacePilotEnabled { PacePilotStatusCard() }
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.sm)
    }
    .safeAreaInset(edge: .bottom) {
      RunLiveControls(
        paused: paused, canPause: canPause, canFinish: canFinish,
        togglePause: { Task { await togglePause() } },
        finish: { Task { await finish() } }
      )
      .disabled(model?.isUpdating == true)
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.sm)
      .background(Theme.Colors.background)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
    .environment(\.colorScheme, .dark)
    .toolbarVisibility(.hidden, for: .navigationBar)
    .statusBarHidden(false)
    .navigationBarBackButtonHidden()
    .task {
      guard let model else { return }
      do {
        try await model.start()
        while !Task.isCancelled {
          await model.updateElapsed()
          try await Task.sleep(for: .seconds(1))
        }
      } catch is CancellationError {
        return
      } catch {
        startFailed = true
        self.error = "Couldn’t start the run."
      }
    }
    .alert(
      "Run recording",
      isPresented: Binding(
        get: { error != nil }, set: { if !$0 { error = nil } }
      ), presenting: error
    ) { _ in
      if startFailed {
        Button("Back to Run", action: onStartFailure)
      } else {
        Button("OK", role: .cancel) {}
      }
    } message: { error in
      Text(error)
    }
  }

  private func togglePause() async {
    do {
      try await model?.togglePause()
    } catch {
      self.error = "Couldn’t change the recording state. Try again."
    }
  }

  private func finish() async {
    do {
      if let savedRun = try await model?.finish() {
        await onFinish(savedRun)
      }
    } catch {
      self.error = "Couldn’t save the run. Use Finish to try again."
    }
  }

}

#Preview("Live · PacePilot on") {
  RunLivePage(goalKilometers: 5, pacePilotEnabled: true, previewDistance: 4.82)
}
