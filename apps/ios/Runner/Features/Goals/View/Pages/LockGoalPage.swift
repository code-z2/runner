import RunnerUI
import SwiftUI

struct LockGoalPage: View {
  let onContinue: (GoalDraft) -> Void

  @Environment(\.locale) private var locale
  @State private var draft = GoalDraft()
  @State private var customDistance: Measurement<UnitLength>?
  @State private var input: Input?
  @State private var amountText = ""

  private enum Input: Equatable { case distance, amount }

  private var enteredAmount: Decimal? {
    let format = Decimal.FormatStyle(locale: locale)
    guard let amount = try? Decimal(amountText, format: format, lenient: false),
      amount > 0
    else { return nil }
    var entered = amount
    var rounded = Decimal.zero
    NSDecimalRound(&rounded, &entered, 2, .plain)
    return rounded == amount ? amount : nil
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
        Text("Put money on your *next goal*")
          .runnerText(.titleLarge)
          .accessibilityAddTraits(.isHeader)
        section("Distance") {
          ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.xs) {
              distanceChip("5K", kilometers: 5)
              distanceChip("10K", kilometers: 10)
              distanceChip("Half", kilometers: 21.0975)
              RunDistanceChip(
                title: customDistance == nil ? "Custom" : LocalizedStringKey(draft.distanceLabel),
                selected: customDistance != nil
              ) { input = .distance }
            }
          }
          .scrollIndicators(.hidden)
        }
        section("Finish under") {
          HStack {
            Button("Decrease time", systemImage: "minus") { draft.minutes -= 1 }
              .disabled(draft.minutes <= 1)
            Spacer()
            Text(draft.timeLabel)
              .runnerText(.metricLarge)
              .minimumScaleFactor(0.5)
              .lineLimit(1)
              .accessibilityLabel("Finish under \(draft.minutes) minutes")
            Spacer()
            Button("Increase time", systemImage: "plus") { draft.minutes += 1 }
              .disabled(draft.minutes >= 1_440)
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.pill(.secondary, compact: true))
          .padding(Theme.Spacing.sm)
          .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        section("Lock") {
          ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.xs) {
              ForEach([10, 25, 50], id: \.self) { amount in
                RunDistanceChip(title: "$\(amount)", selected: draft.amount == Decimal(amount)) {
                  draft.amount = Decimal(amount)
                }
              }
              let isCustom = ![10, 25, 50].map { Decimal($0) }.contains(draft.amount)
              RunDistanceChip(
                title: isCustom ? LocalizedStringKey(draft.amountLabel) : "Custom",
                selected: isCustom
              ) {
                amountText = draft.amount.formatted(.number.locale(locale))
                input = .amount
              }
            }
          }
          .scrollIndicators(.hidden)
        }
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          Text("How it works")
            .runnerText(.eyebrow)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          Text("•  Beat your goal to unlock the funds.")
          Text("•  Unlocked funds stay in escrow until you move them out.")
          Text("•  If you give up, half comes back to you and half goes to the pool.")
        }
        .runnerText(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.lg)
    }
    .safeAreaInset(edge: .bottom) {
      Button("Continue to funding") { onContinue(draft) }
        .buttonStyle(.pill())
        .padding(.horizontal, Theme.Spacing.screenInset)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
    .navigationTitle("Lock a goal")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: presentation(for: .distance)) {
      DistanceSheet(selection: customDistance) { distance in
        draft.distance = distance
        customDistance = distance
      }
    }
    .alert("Custom amount", isPresented: presentation(for: .amount)) {
      TextField("Amount in USD", text: $amountText)
        .keyboardType(.decimalPad)
      Button("Cancel", role: .cancel) {}
      Button("Use amount") {
        if let enteredAmount { draft.amount = enteredAmount }
      }
      .disabled(enteredAmount == nil)
    } message: {
      Text("Enter a positive amount in USD, up to two decimal places.")
    }
  }

  private func section<Content: View>(
    _ title: LocalizedStringKey, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
      Text(title)
        .runnerText(.eyebrow)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
        .accessibilityAddTraits(.isHeader)
      content()
    }
  }

  private func distanceChip(_ title: LocalizedStringKey, kilometers: Double) -> some View {
    let distance = Measurement(value: kilometers, unit: UnitLength.kilometers)
    return RunDistanceChip(
      title: title, selected: customDistance == nil && draft.distance == distance
    ) {
      draft.distance = distance
      customDistance = nil
    }
  }

  private func presentation(for item: Input) -> Binding<Bool> {
    Binding(get: { input == item }, set: { if !$0 { input = nil } })
  }
}

#Preview("Lock a goal") {
  NavigationStack { LockGoalPage(onContinue: { _ in }) }
}
