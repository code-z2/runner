import RunnerUI
import SwiftUI

struct RunHistoryPage: View {

  let runs: [RunSummary]
  let unavailable: Bool

  @Environment(\.calendar)
  private var calendar

  private var months: [Date: [RunSummary]] {
    Dictionary(grouping: runs) {
      calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
    }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        if runs.isEmpty {
          Text(unavailable ? "History unavailable" : "No activity yet")
            .runnerText(.titleSmall)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.section)
        } else {
          RunPersonalBests(metrics: RunHistoryMetrics(runs: runs))
          let grouped = months
          ForEach(grouped.keys.sorted(by: >), id: \.self) { month in
            Section {
              ForEach(grouped[month, default: []]) { run in
                VStack(spacing: 0) {
                  NavigationLink(value: HomeDestination.savedSummary(run)) {
                    RunHistoryRow(run: run)
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .contentShape(Rectangle())
                  }
                  .buttonStyle(.plain)
                  Rectangle().fill(Theme.Colors.border).frame(height: Theme.Sizing.hairline)
                    .accessibilityHidden(true)
                }
              }
            } header: {
              Text(month, format: monthFormat(month))
                .runnerText(.eyebrow)
                .foregroundStyle(Theme.Colors.foregroundSecondary)
                .accessibilityAddTraits(.isHeader)
            }
          }
        }
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.sm)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
    .navigationTitle("History")
    .navigationBarTitleDisplayMode(.inline)
    .tint(Theme.Colors.foreground)
  }

  private func monthFormat(_ month: Date) -> Date.FormatStyle {
    calendar.isDate(month, equalTo: .now, toGranularity: .year)
      ? .dateTime.month(.wide) : .dateTime.month(.wide).year()
  }
}

#if DEBUG
  #Preview("History") {
    NavigationStack {
      RunHistoryPage(
        runs: [
          (5_120.0, 1541.0, 0), (3_400, 1082, 1), (10_000, 3130, 3),
          (2_800, 910, 5), (12_400, 4008, 7), (5_000, 1498, 12),
        ]
        .map { distance, elapsed, days in
          RunSummary(
            id: UUID(), distanceMeters: distance, elapsed: elapsed,
            date: .now.addingTimeInterval(-Double(days) * 86_400))
        },
        unavailable: false)
    }
  }
#endif
