import RunnerUI
import SwiftUI
import UIKit

struct IntentDepositSheet: View {
  let heading: LocalizedStringKey
  let amount: String
  let asset: String
  let network: String
  let address: String
  var memo: String?
  var deadline: Date?
  let onDone: () -> Void

  @State private var copied = false
  @State private var copiedMemo = false

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let payable = deadline.map { $0 > context.date } ?? true
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
          if payable {
            depositDetails
          } else {
            Text(
              "These deposit instructions have expired. Check your goal’s status before sending funds."
            )
            .runnerText(.footnote)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          }
        }
        .padding(.horizontal, Theme.Spacing.screenInset)
        .padding(.top, Theme.Spacing.xl)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .safeAreaInset(edge: .bottom) {
      Button("Done", action: onDone)
        .buttonStyle(.pill())
        .padding(.horizontal, Theme.Spacing.screenInset)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
    .presentationDetents([.medium])
    .presentationDragIndicator(.hidden)
    .interactiveDismissDisabled()
  }

  private var depositDetails: some View {
    Group {
      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        Text(heading)
          .runnerText(.eyebrow)
          .foregroundStyle(Theme.Colors.primary)
        Text("\(amount) \(asset)")
          .runnerText(.metricLarge)
        Text("Send on \(network)")
          .runnerText(.titleSmall)
      }
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)

      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        Text("Deposit address")
          .runnerText(.eyebrow)
        Text(address)
          .font(.system(.subheadline, design: .monospaced))
          .textSelection(.enabled)
        Button {
          UIPasteboard.general.string = address
          copied = true
        } label: {
          Label(
            copied ? "Copied" : "Copy address",
            systemImage: copied ? "checkmark" : "document.on.document")
        }
        .buttonStyle(.pill(.secondary, compact: true))

        if let memo, !memo.isEmpty {
          Divider()
          Text("Required memo")
            .runnerText(.eyebrow)
          Text(memo)
            .font(.system(.subheadline, design: .monospaced))
            .textSelection(.enabled)
          Button {
            UIPasteboard.general.string = memo
            copiedMemo = true
          } label: {
            Label(
              copiedMemo ? "Memo copied" : "Copy memo",
              systemImage: copiedMemo ? "checkmark" : "document.on.document")
          }
          .buttonStyle(.pill(.secondary, compact: true))
        }
      }
      .padding(.horizontal, Theme.Spacing.md)
      .padding(.vertical, Theme.Spacing.sm)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

      if let deadline {
        Text(
          "Send the exact amount before \(deadline.formatted(date: .abbreviated, time: .shortened))."
        )
        .runnerText(.footnote)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
      }
      Text("Sending from an exchange? We advise you deposit from an address that belongs to you.")
        .runnerText(.footnote)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
    }
  }
}

#Preview("Goal deposit") {
  Color.clear.sheet(isPresented: .constant(true)) {
    IntentDepositSheet(
      heading: "Sample deposit", amount: "25", asset: "USDC", network: "Base",
      address: "0x71c4b9a0e83dPREVIEWa5526f0c92c7a41e09d", onDone: {})
  }
}
