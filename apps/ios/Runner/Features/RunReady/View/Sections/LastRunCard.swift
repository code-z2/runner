import RunnerUI
import SwiftUI

struct LastRunCard: View {

  let run: RunSummary
  let showHistory: () -> Void

  @Environment(\.locale)
  private var locale

  @Environment(\.dynamicTypeSize)
  private var dynamicType

  var body: some View {
    NavigationLink(value: HomeDestination.savedSummary(run)) {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        HStack {
          Text("Last run · \(run.date.formatted(.dateTime.weekday(.wide).locale(locale)))")
            .runnerText(.eyebrow)
            .accessibilityAddTraits(.isHeader)
          Spacer(minLength: Theme.Spacing.xs)
          Text("View all")
            .runnerText(.caption)
            .frame(minWidth: Theme.Sizing.tapTargetMin, minHeight: Theme.Sizing.tapTargetMin)
            .hidden()
        }
        ReadyRunMetrics(run: run, vertical: dynamicType.isAccessibilitySize)
      }
      .padding(.horizontal, Theme.Spacing.md)
      .padding(.bottom, Theme.Spacing.lg)
      .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .overlay(alignment: .topTrailing) {
      Button(action: showHistory) {
        Text("View all")
          .runnerText(.caption)
          .frame(minWidth: Theme.Sizing.tapTargetMin, minHeight: Theme.Sizing.tapTargetMin)
          .contentShape(Rectangle())
      }
      .buttonStyle(ReadyButtonStyle())
      .foregroundStyle(Theme.Colors.actionText)
      .accessibilityLabel("View all runs")
      .padding(.trailing, Theme.Spacing.md)
    }
    .padding(.horizontal, Theme.Spacing.screenInset)
  }
}
