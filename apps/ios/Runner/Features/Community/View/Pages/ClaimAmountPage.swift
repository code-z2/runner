import RunnerUI
import SwiftUI

struct ClaimAmountPage: View {
  let place: CommunityPlace
  let claimable: Decimal
  let balance: Decimal
  /// Pays `amount` and moves on; throws to stay on this page.
  var onConfirm: (Decimal) async throws -> Void = { _ in }

  @Environment(\.locale) private var locale
  @State private var entry = ""
  @State private var paying = false
  @State private var failure: String?

  private var separator: String { locale.decimalSeparator ?? "." }
  private var amount: Decimal { Decimal(string: entry, locale: locale) ?? 0 }
  private var canConfirm: Bool { amount > 0 && amount <= claimable && amount <= balance }

  var body: some View {
    ScrollView {
      VStack(spacing: Theme.Spacing.xl) {
        HStack(spacing: Theme.Spacing.md) {
          Text(String(place.name.prefix(1)))
            .runnerText(.titleSmall)
            .foregroundStyle(Theme.Colors.primary)
            .frame(width: Theme.Sizing.tapTargetMin, height: Theme.Sizing.tapTargetMin)
            .background(Theme.Colors.secondary, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: Theme.Spacing.hair) {
            Text(place.name).runnerText(.headline)
            Text("\(place.account) · verified partner")
              .runnerText(.footnote)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
          }
          Spacer()
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

        VStack(spacing: Theme.Spacing.xs) {
          Text(amount.formatted(.currency(code: "USD")))
            .runnerText(.metricLarge)
          Text("of \(claimable.formatted(.currency(code: "USD"))) on your pass")
            .runnerText(.footnote)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
        }
        .padding(.vertical, Theme.Spacing.lg)
        .accessibilityElement(children: .combine)

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          if balance < claimable {
            Text("Club funds low")
              .runnerText(.callout)
              .foregroundStyle(Theme.Colors.primary)
            Text(
              "Only \(balance.formatted(.currency(code: "USD"))) available in the club pool.")
          }
          Text("One claim per run. Anything you don’t spend is not kept.")
        }
        .runnerText(.footnote)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
      }
      .padding(Theme.Spacing.screenInset)
    }
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: Theme.Spacing.md) {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
          ForEach(0..<4) { row in
            GridRow {
              ForEach(0..<3) { column in
                let key = ["1", "2", "3", "4", "5", "6", "7", "8", "9", separator, "0", "delete"][
                  row * 3 + column]
                Button {
                  enter(key)
                } label: {
                  Group {
                    if key == "delete" {
                      Image(systemName: "delete.left")
                    } else {
                      Text(key)
                    }
                  }
                  .runnerText(.statLight)
                  .frame(maxWidth: .infinity, minHeight: Theme.Sizing.tapTargetMin)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key == "delete" ? "Delete digit" : key)
              }
            }
          }
        }
        Button(paying ? "Paying…" : "Confirm \(amount.formatted(.currency(code: "USD")))") {
          confirm()
        }
        .buttonStyle(.pill())
        .disabled(!canConfirm || paying)
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.bottom, Theme.Spacing.sm)
      .background(Theme.Colors.background)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
    .navigationTitle("Pay at \(place.name)")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .navigationBarBackButtonHidden(paying)
    .environment(\.colorScheme, .dark)
    .alert(
      "Claim not paid",
      isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(failure ?? "")
    }
  }

  private func confirm() {
    guard canConfirm, !paying else { return }
    paying = true
    Task {
      defer { paying = false }
      do {
        try await onConfirm(amount)
      } catch {
        failure = Self.message(for: error)
      }
    }
  }

  private static func message(for error: any Error) -> String {
    switch error as? CommunityServiceError {
    case .passUsed:
      String(localized: "This pass is already spent or expired.")
    case .notAccepted:
      String(localized: "The club pool couldn’t pay this claim. Your pass is still valid.")
    case .awaitingCouncil:
      String(localized: "Your claim is waiting for the council to approve it.")
    case .failed:
      String(localized: "This place can’t take claims right now. Your pass is still valid.")
    case .invalidAmount, .invalidQuote, nil:
      String(localized: "We couldn’t confirm the payment. Try again.")
    }
  }

  private func enter(_ key: String) {
    if key == "delete" {
      if !entry.isEmpty { entry.removeLast() }
    } else if key == separator {
      guard !entry.contains(separator) else { return }
      if entry.isEmpty { entry = "0" }
      entry += separator
    } else if let decimal = entry.range(of: separator) {
      if entry[decimal.upperBound...].count < 2 { entry += key }
    } else if entry.count < 5 {
      entry = entry == "0" ? key : entry + key
    }
  }
}

#Preview("Claim amount") {
  NavigationStack {
    ClaimAmountPage(place: CommunityPreviewData.places[0], claimable: 2.56, balance: 4_820)
  }
}

#Preview("Community funds low") {
  NavigationStack {
    ClaimAmountPage(place: CommunityPreviewData.places[0], claimable: 2.56, balance: 1.25)
  }
}
