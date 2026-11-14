import RunnerUI
import SwiftUI

struct CommunityPage: View {
  var balance = CommunityPreviewData.balance
  var places = CommunityPreviewData.places
  var placesUnavailable = false
  var onFund: () -> Void = {}
  var onClaim: (CommunityPlace) -> Void = { _ in }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.section) {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.hair) {
              Text("Club pool")
                .runnerText(.eyebrow)
                .foregroundStyle(Theme.Colors.primary)
              Text(
                "\(balance.formatted(.currency(code: "USD").precision(.fractionLength(0...2)))) to spend on places"
              )
              .runnerText(.callout)
            }
            Spacer(minLength: Theme.Spacing.sm)
            Button("Fund", action: onFund)
              .buttonStyle(.pill(.primary, compact: true))
              .accessibilityLabel("Fund the pool")
          }
          Text(
            "A free claim balance for runners to spend on after-run essentials like water. Available globally."
          )
          .runnerText(.footnote)
          .foregroundStyle(Theme.Colors.foregroundSecondary)
          .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .background(
          Theme.Colors.highlightSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
          VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Places *near you*")
              .runnerText(.titleLarge)
              .accessibilityAddTraits(.isHeader)
            Text("Partner spots that take claim passes. Walk in, scan their code, done.")
              .runnerText(.body)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
          }

          if places.isEmpty {
            Text(
              placesUnavailable
                ? "Turn on location to see partner places near you."
                : "No partner places near you yet."
            )
            .runnerText(.footnote)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          }

          if let nearest = places.first {
            Button {
              onClaim(nearest)
            } label: {
              Color.clear
                .aspectRatio(2.57, contentMode: .fit)
                .overlay {
                  Image(.placesStorefront)
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
                }
                .clipped()
                .overlay(alignment: .bottomLeading) {
                  VStack(alignment: .leading, spacing: Theme.Spacing.hair) {
                    Text("Nearest · \(nearest.name)").runnerText(.callout)
                    Text(nearest.distance)
                      .runnerText(.footnote)
                      .foregroundStyle(Theme.Colors.foregroundSecondary)
                  }
                  .padding(Theme.Spacing.sm)
                  .background(
                    Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Radius.sm)
                  )
                  .padding(Theme.Spacing.sm)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
            .buttonStyle(.plain)
          }

          VStack(spacing: 0) {
            ForEach(places) { place in
              Button {
                onClaim(place)
              } label: {
                HStack(spacing: Theme.Spacing.md) {
                  Text(String(place.name.prefix(1)))
                    .runnerText(.titleSmall)
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: Theme.Sizing.tapTargetMin, height: Theme.Sizing.tapTargetMin)
                    .background(
                      Theme.Colors.secondary, in: RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    )
                    .accessibilityHidden(true)
                  Text(place.name).runnerText(.headline)
                  Spacer()
                  Text(place.distance)
                    .runnerText(.footnote)
                    .foregroundStyle(Theme.Colors.foregroundSecondary)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              if place.id != places.last?.id { Divider() }
            }
          }
        }
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.lg)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
    .navigationTitle("Club")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview("Community and Places") {
  NavigationStack { CommunityPage() }
}

#Preview("No places yet") {
  NavigationStack { CommunityPage(balance: 0, places: []) }
}
