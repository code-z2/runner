import RunnerUI
import SwiftUI

struct ClaimDonePage: View {
  let receipt: ClaimReceipt
  let onDone: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: Theme.Spacing.xl) {
        Image(systemName: "checkmark")
          .runnerText(.title)
          .foregroundStyle(Theme.Colors.primary)
          .padding(Theme.Spacing.section)
          .background(Theme.Colors.highlightSurface, in: Circle())
          .accessibilityHidden(true)
        Text("Paid")
          .runnerText(.display.italicized)
          .accessibilityAddTraits(.isHeader)
        Text("\(receipt.amount.formatted(.currency(code: "USD"))) to \(receipt.place.name)")
          .runnerText(.headline)
        Text("Show this screen at the counter.")
          .runnerText(.body)
          .foregroundStyle(Theme.Colors.foregroundSecondary)
      }
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(Theme.Spacing.screenInset)
      .containerRelativeFrame(.vertical)
    }
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: Theme.Spacing.lg) {
        VStack(spacing: Theme.Spacing.sm) {
          LabeledContent("Time", value: receipt.paidAt.formatted(date: .omitted, time: .shortened))
          LabeledContent("Pass", value: receipt.passLabel)
          LabeledContent("Transaction", value: receipt.shortHash)
        }
        .runnerText(.footnote)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        Button("Done", action: onDone)
          .buttonStyle(.pill(.secondary))
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.bottom, Theme.Spacing.sm)
      .background(Theme.Colors.background)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
    .toolbarVisibility(.hidden, for: .navigationBar)
    .environment(\.colorScheme, .dark)
  }
}

#Preview("Claim done") {
  ClaimDonePage(receipt: CommunityPreviewData.receipt, onDone: {})
}
