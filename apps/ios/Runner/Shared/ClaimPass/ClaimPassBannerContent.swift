import RunnerUI
import SwiftUI

struct ClaimPassBannerContent: View {

  let amountCents: Int
  let remaining: TimeInterval
  let communityBalanceLow: Bool
  let actionable: Bool

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: Theme.Spacing.hair) {
        Text(communityBalanceLow ? "Claim pass" : "Claim pass ready")
          .runnerText(.subheadlineMedium)
        if communityBalanceLow {
          Text("Community balance is low")
            .runnerText(.caption)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
        } else {
          let amount = (Decimal(amountCents) / 100).formatted(.currency(code: "USD"))
          let time = Duration.seconds(remaining.rounded(.up)).formatted(
            .time(pattern: .hourMinuteSecond))
          Text("Up to \(amount) · \(time) left")
            .runnerText(.caption)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
        }
      }
      Spacer(minLength: 0)
      if actionable {
        Image(systemName: "chevron.forward")
          .font(.caption)
          .accessibilityHidden(true)
      }
    }
    .padding(Theme.Spacing.md)
    .frame(minHeight: Theme.Sizing.tapTargetMin)
    .background(
      Theme.Colors.highlightSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.card)
    )
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}
