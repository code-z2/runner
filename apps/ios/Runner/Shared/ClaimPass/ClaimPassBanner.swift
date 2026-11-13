import RunnerGateway
import RunnerUI
import SwiftUI

struct ClaimPassBanner: View {

  let pass: ClaimPass
  let communityBalanceLow: Bool
  let action: (() -> Void)?

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = TimeInterval(pass.expiresAt) - context.date.timeIntervalSince1970
      if pass.maxAmountCents > 0, remaining > 0 {
        if !communityBalanceLow, let action {
          Button(action: action) {
            ClaimPassBannerContent(
              amountCents: pass.maxAmountCents, remaining: remaining,
              communityBalanceLow: false, actionable: true)
          }
          .buttonStyle(.plain)
        } else {
          ClaimPassBannerContent(
            amountCents: pass.maxAmountCents, remaining: remaining,
            communityBalanceLow: communityBalanceLow, actionable: false)
        }
      }
    }
  }
}
