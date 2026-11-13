import RunnerGateway
import RunnerUI
import SwiftUI

struct RunSummaryPage: View {

  let elapsed: TimeInterval
  var date: Date = .now
  var distanceKilometers: Double?
  var cadence: Int?
  var encounters: RunEncounters?
  var splits: [TimeInterval] = []
  var achievement: LocalizedStringKey?
  var claimPass: ClaimPass?
  var communityBalanceLow = false
  var openClaim: (() -> Void)?
  var healthConnection: RunLiveViewModel?
  var showsLatestHealthExport = false

  @State
  private var exporting = false

  @Environment(\.scenePhase)
  private var scenePhase

  @State
  private var exportFailed = false

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        Color.clear
          .frame(height: Theme.Spacing.screenTop * 2 + Theme.Spacing.section)
          .overlay {
            Image(.summaryShoes).resizable().scaledToFill()
              .accessibilityHidden(true)
          }
          .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
          .overlay(alignment: .topLeading) {
            if let achievement {
              HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "star.fill")
                  .foregroundStyle(Theme.Colors.primary)
                  .accessibilityHidden(true)
                Text(achievement)
              }
              .runnerText(.caption)
              .padding(.horizontal, Theme.Spacing.md)
              .padding(.vertical, Theme.Spacing.xs)
              .background(Theme.Colors.surfaceRaised, in: Capsule())
              .padding(Theme.Spacing.md)
            }
          }

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text(date, format: .dateTime.weekday(.wide).hour().minute())
            .runnerText(.caption)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          Text("\(daypart) *run*")
            .runnerText(.title)
            .accessibilityAddTraits(.isHeader)
        }

        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
          Text(distanceKilometers?.formatted(.number.precision(.fractionLength(2))) ?? "—")
            .runnerText(.metricLarge)
          Text("km").runnerText(.body).foregroundStyle(Theme.Colors.foregroundSecondary)
        }

        let layout =
          dynamicType.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.md))
          : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.sm))
        layout {
          RunMetric(label: "Time", value: time(elapsed))
          RunMetric(
            label: "Avg pace",
            value: distanceKilometers.flatMap {
              $0 > 0 ? RunHistoryMetrics.paceMinutes(elapsed / $0) : nil
            },
            unit: "min/km")
          RunMetric(label: "Cadence", value: cadence?.formatted(), unit: "spm")
        }

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          Text("Runners crossed").runnerText(.eyebrow)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          layout {
            RunMetric(label: "New", value: (encounters?.new ?? 0).formatted())
            RunMetric(label: "Again", value: (encounters?.again ?? 0).formatted())
            RunMetric(label: "Ran together", value: (encounters?.together ?? 0).formatted())
          }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text("Splits").runnerText(.eyebrow)
          if splits.isEmpty {
            Text("No splits recorded").runnerText(.caption)
          }
          ForEach(splitSamples) { sample in
            HStack(spacing: Theme.Spacing.sm) {
              Text("\(sample.id + 1) km").frame(
                minWidth: Theme.Sizing.tapTargetMin, alignment: .leading)
              ProgressView(value: sample.seconds, total: splits.max() ?? sample.seconds)
                .tint(Theme.Colors.primary)
                .accessibilityHidden(true)
              Text(time(sample.seconds))
            }
            .runnerText(.caption)
            .accessibilityElement(children: .combine)
          }
        }
        .foregroundStyle(Theme.Colors.foregroundSecondary)
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

        if let healthConnection { healthSection(healthConnection) }

        if let claimPass {
          ClaimPassBanner(
            pass: claimPass, communityBalanceLow: communityBalanceLow, action: openClaim)
        }
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.sm)
    }
    .background(Theme.Colors.background.ignoresSafeArea())
    .foregroundStyle(Theme.Colors.foreground)
    .navigationTitle("Run summary")
    .navigationBarTitleDisplayMode(.inline)
    .tint(Theme.Colors.foreground)
    .task(id: scenePhase) {
      if scenePhase == .active { healthConnection?.refreshHealthAccess() }
    }
    .alert("Apple Health access unavailable", isPresented: $exportFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(
        "Allow Runner to write Workouts in Apple Health. Walking + Running Distance is optional.")
    }
  }

  private func healthSection(_ model: RunLiveViewModel) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
      HStack(spacing: Theme.Spacing.sm) {
        Image(.appleHealthIcon)
          .resizable()
          .scaledToFit()
          .frame(width: Theme.Sizing.iconMd, height: Theme.Sizing.iconMd)
          .accessibilityHidden(true)
        Text("Apple Health").runnerText(.bodyMedium)
      }
      if model.isHealthConnected {
        Text("Connected • Runs are saved automatically")
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: Theme.Spacing.xs) {
            Text("Disconnected •").fixedSize()
            connectHealthButton(model).fixedSize()
          }
          VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Disconnected")
            connectHealthButton(model)
          }
        }
      }
      if showsLatestHealthExport, model.healthExportFailed {
        Text("The latest run stayed in Runner. Apple Health couldn’t save it.")
      }
    }
    .runnerText(.caption)
  }

  private func connectHealthButton(_ model: RunLiveViewModel) -> some View {
    Button {
      exporting = true
      Task {
        defer { exporting = false }
        do {
          try await model.enableHealthExport()
        } catch {
          exportFailed = true
        }
      }
    } label: {
      Text("Click to connect")
        .underline()
        .foregroundStyle(Theme.Colors.actionText)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Connect Apple Health")
    .disabled(exporting)
  }

  private var daypart: String {
    switch Calendar.current.component(.hour, from: date) {
    case 5..<12: "Morning"
    case 12..<18: "Afternoon"
    case 18..<23: "Evening"
    default: "Night"
    }
  }

  private var splitSamples: [RunSplit] {
    splits.enumerated().map { RunSplit(id: $0.offset, seconds: $0.element) }
  }

  private func time(_ seconds: TimeInterval) -> String {
    Duration.seconds(seconds.rounded()).formatted(
      .time(pattern: seconds >= 3_600 ? .hourMinuteSecond : .minuteSecond))
  }
}

#if DEBUG
  #Preview("Summary · Pass ready") {
    NavigationStack {
      RunSummaryPage(
        elapsed: 1541, distanceKilometers: 5.12, cadence: 171,
        encounters: RunEncounters(new: 3, again: 1, together: 1),
        splits: [304, 300, 298, 302, 305], achievement: "Fastest 5K this month",
        claimPass: .init(
          version: 1, accountID: "", activityHash: "", maxAmountCents: 256,
          expiresAt: Int(Date.now.timeIntervalSince1970) + 7000, nonce: "", signature: ""),
        openClaim: {})
    }
  }

  #Preview("Summary · Community balance low") {
    NavigationStack {
      RunSummaryPage(
        elapsed: 1541, distanceKilometers: 5.12, cadence: 171,
        encounters: RunEncounters(new: 3, again: 1, together: 1),
        splits: [304, 300, 298, 302, 305], achievement: "Fastest 5K this month",
        claimPass: .init(
          version: 1, accountID: "", activityHash: "", maxAmountCents: 256,
          expiresAt: Int(Date.now.timeIntervalSince1970) + 7000, nonce: "", signature: ""),
        communityBalanceLow: true)
    }
  }
  #Preview("Summary · Outside claim window") {
    NavigationStack {
      RunSummaryPage(
        elapsed: 1541, distanceKilometers: 5.12,
        claimPass: .init(
          version: 1, accountID: "", activityHash: "", maxAmountCents: 256,
          expiresAt: 1, nonce: "", signature: ""),
        communityBalanceLow: true)
    }
  }
#endif
