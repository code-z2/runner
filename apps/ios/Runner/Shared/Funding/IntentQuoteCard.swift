import RunnerUI
import SwiftUI

struct IntentQuoteCard: View {
  let heading: LocalizedStringKey
  let recipientLabel: LocalizedStringKey
  let sends: String
  let receives: String
  let returnAddress: String
  var canEditReturnAddress = true
  let onEditReturnAddress: () -> Void

  private var displayedReturnAddress: String {
    if returnAddress.count <= 18 { return returnAddress }
    return "\(returnAddress.prefix(8))…\(returnAddress.suffix(6))"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      Text(heading)
        .runnerText(.eyebrow)
        .accessibilityAddTraits(.isHeader)
      quoteRow("You send", value: sends)
      quoteRow(recipientLabel, value: receives, highlighted: true)
      quoteRow("Swap by", value: "NEAR Intents")
      Divider()
      HStack(spacing: Theme.Spacing.sm) {
        Text("Return address").foregroundStyle(Theme.Colors.foregroundSecondary)
        Spacer(minLength: 0)
        Button(action: onEditReturnAddress) {
          if returnAddress.isEmpty {
            Label {
              Text("Edit").underline()
            } icon: {
              Image(systemName: "pencil")
            }
          } else {
            Text(displayedReturnAddress)
          }
        }
        .buttonStyle(.plain)
        .disabled(!canEditReturnAddress)
        .foregroundStyle(Theme.Colors.primary)
        .accessibilityLabel("Edit return address")
        .accessibilityValue(returnAddress)
      }
      .runnerText(.footnote)
    }
    .padding(Theme.Spacing.md)
    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
  }

  private func quoteRow(
    _ title: LocalizedStringKey, value: String, highlighted: Bool = false
  ) -> some View {
    let foreground = highlighted ? Theme.Colors.primary : Theme.Colors.foreground
    return ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .foregroundStyle(Theme.Colors.foregroundSecondary)
          .fixedSize()
        Spacer(minLength: Theme.Spacing.md)
        Text(value)
          .foregroundStyle(foreground)
          .fixedSize()
      }

      VStack(alignment: .leading, spacing: Theme.Spacing.hair) {
        Text(title).foregroundStyle(Theme.Colors.foregroundSecondary)
        Text(value)
          .foregroundStyle(foreground)
      }
    }
    .runnerText(.footnote)
    .accessibilityElement(children: .combine)
  }
}

#Preview("Edited return address") {
  IntentQuoteCard(
    heading: "Sample quote", recipientLabel: "Goal escrow receives",
    sends: "25 USDC on Base", receives: "25 USDC on NEAR",
    returnAddress: "0x7a1b3d020839f8fc319D62112f7D14Db61AD44be", onEditReturnAddress: {}
  )
  .padding(Theme.Spacing.screenInset)
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Theme.Colors.background)
}
