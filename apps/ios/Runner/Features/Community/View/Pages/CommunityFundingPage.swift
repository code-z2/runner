import RunnerNear
import RunnerUI
import SwiftUI

struct CommunityFundingPage: View {
  let balance: Decimal
  /// Payable quote for (USDC amount, source network, return address). Nil
  /// shows the sample.
  var requestQuote: ((Decimal, FundingNetwork, String) async throws -> IntentQuote)?
  /// The deposit sheet was closed after a live quote.
  var onFunded: () -> Void = {}
  /// In the app without a funding service: no sample, Continue disabled.
  var unavailable = false
  @State private var amount: Decimal = 20
  @State private var amountInput = ""
  @State private var editingAmount = false
  @State private var network = FundingNetwork.base
  @State private var showingDeposit = false
  @State private var returnAddress = ""
  @State private var addressInput = ""
  @State private var editingReturnAddress = false
  @State private var requestingQuote = false
  @State private var liveDeposit: PoolDeposit?
  @State private var failure: LocalizedStringKey?

  private var isSample: Bool { requestQuote == nil && !unavailable }
  private let asset = "USDC"
  private var sourceAmount: String { amount.formatted() }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text("Club pool").runnerText(.eyebrow)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text(balance.formatted(.currency(code: "USD").precision(.fractionLength(0...2))))
              .runnerText(.metricLarge)
            Text("USDC").runnerText(.body)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text("Send from any chain").runnerText(.eyebrow)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          ViewThatFits(in: .horizontal) {
            networkRow([.base, .ethereum, .solana, .arbitrum])
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
              networkRow([.base, .ethereum])
              networkRow([.solana, .arbitrum])
            }
          }
          networkRow([.bnb, .polygon, .sui])
        }

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text("Amount").runnerText(.eyebrow)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          HStack {
            Text(sourceAmount).runnerText(.metric)
            Spacer()
            Text(asset).runnerText(.footnote)
              .padding(.horizontal, Theme.Spacing.md)
              .padding(.vertical, Theme.Spacing.xs)
              .background(Theme.Colors.secondary, in: Capsule())
          }
          .padding(Theme.Spacing.md)
          .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
          HStack(spacing: Theme.Spacing.xs) {
            ForEach(Self.presets, id: \.self) { option in
              RunDistanceChip(title: "$\(option.formatted())", selected: amount == option) {
                amount = option
              }
            }
            RunDistanceChip(title: "Other", selected: !Self.presets.contains(amount)) {
              amountInput = Self.presets.contains(amount) ? "" : amount.formatted()
              editingAmount = true
            }
          }
          .disabled(requestingQuote)
        }

        if isSample {
          IntentQuoteCard(
            heading: nil, recipientLabel: "Pool receives",
            sends: "\(sourceAmount) \(asset) on \(network.title)",
            receives:
              "≈ \((amount * Decimal(0.998)).formatted(.number.precision(.fractionLength(2)))) USDC on NEAR",
            returnAddress: "", onEditReturnAddress: nil)
        } else {
          IntentQuoteCard(
            heading: nil, recipientLabel: "Pool receives",
            sends: String(localized: "Quoted in USDC on \(network.title)"),
            receives: "\(amount.formatted()) USDC on NEAR",
            returnAddress: returnAddress, canEditReturnAddress: !requestingQuote,
            onEditReturnAddress: {
              addressInput = returnAddress
              editingReturnAddress = true
            })
        }
        Text(
          unavailable
            ? "Pool funding isn’t available right now."
            : "Gifts to the pool pay for runners’ claims at partner places. They can’t be taken back."
        )
        .runnerText(.footnote)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.lg)
    }
    .safeAreaInset(edge: .bottom) {
      Button(requestingQuote ? "Getting quote…" : "Continue", action: continueFunding)
        .buttonStyle(.pill())
        .disabled(requestingQuote || unavailable || (!isSample && returnAddress.isEmpty))
        .padding(.horizontal, Theme.Spacing.screenInset)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
    .navigationTitle("Fund the pool")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(requestingQuote)
    .onChange(of: network, initial: true) {
      returnAddress = UserDefaults.standard.string(forKey: network.returnAddressKey) ?? ""
    }
    .sheet(isPresented: $showingDeposit) {
      IntentDepositSheet(
        heading: "Sample deposit", amount: sourceAmount, asset: asset, network: network.title,
        address: "Example deposit address", onDone: { showingDeposit = false })
    }
    .sheet(item: $liveDeposit) { deposit in
      IntentDepositSheet(
        heading: "Pool deposit", amount: deposit.amount, asset: "USDC",
        network: deposit.network.title,
        address: deposit.address, memo: deposit.memo, deadline: deposit.deadline,
        onDone: {
          liveDeposit = nil
          onFunded()
        })
    }
    .alert("Amount", isPresented: $editingAmount) {
      TextField("USDC", text: $amountInput)
        .keyboardType(.decimalPad)
      Button("Cancel", role: .cancel) {}
      Button("Use") {
        if let value = Self.amount(from: amountInput) { amount = value }
      }
    } message: {
      Text("USDC the pool receives, up to two decimals.")
    }
    .alert("Return address", isPresented: $editingReturnAddress) {
      TextField("Wallet address", text: $addressInput)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
      Button("Cancel", role: .cancel) {}
      Button("Save") {
        returnAddress = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
      }
    } message: {
      Text("Enter a wallet address for USDC on \(network.title). Refunds go here.")
    }
    .alert(
      "Fund the pool",
      isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(failure ?? "")
    }
  }

  private func continueFunding() {
    guard let requestQuote else {
      showingDeposit = true
      return
    }
    let address = returnAddress
    let source = network
    guard source.isValid(returnAddress: address) else {
      failure = "Enter a valid \(source.title) wallet address for USDC."
      return
    }
    requestingQuote = true
    Task {
      defer { requestingQuote = false }
      do {
        let quote = try await requestQuote(amount, source, address)
        UserDefaults.standard.set(address, forKey: source.returnAddressKey)
        if let deposit = PoolDeposit(quote: quote, network: source), deposit.deadline > .now {
          liveDeposit = deposit
        } else {
          failure = "We couldn’t confirm your quote. Try again."
        }
      } catch NearError.relayer(let status, _) where status == 503 {
        failure = "Pool funding is temporarily paused."
      } catch NearError.relayer(_, let message) where Self.minimum(in: message) != nil {
        let minimum = Self.minimum(in: message) ?? 0
        failure =
          "The smallest gift from \(source.title) is \(minimum.formatted(.number.precision(.fractionLength(0...2)))) USDC."
      } catch {
        failure = "We couldn’t confirm your quote. Try again."
      }
    }
  }

  private static let presets: [Decimal] = [5, 10, 20, 50]

  /// A typed amount: positive, at most two decimals, under $100,000.
  nonisolated static func amount(from text: String, locale: Locale = .current) -> Decimal? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard let value = Decimal(string: trimmed, locale: locale), value > 0, value < 100_000
    else { return nil }
    var scaled = value * 100
    var rounded = Decimal()
    NSDecimalRound(&rounded, &scaled, 0, .plain)
    return rounded == scaled ? value : nil
  }

  /// 1Click's "Amount is too low for bridge, try at least 149983" as USDC.
  nonisolated static func minimum(in message: String) -> Decimal? {
    guard message.hasPrefix("Amount is too low"),
      let units = message.split(separator: " ").last.flatMap({ Decimal(string: String($0)) })
    else { return nil }
    return units / 1_000_000
  }

  private func networkRow(_ networks: [FundingNetwork]) -> some View {
    HStack(spacing: Theme.Spacing.xs) {
      ForEach(networks) { option in
        RunDistanceChip(title: LocalizedStringKey(option.title), selected: network == option) {
          network = option
        }
        .disabled(requestingQuote)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
  }
}

#Preview("Fund the pool") {
  NavigationStack { CommunityFundingPage(balance: CommunityPreviewData.balance) }
}

#Preview("Fund the pool · Unavailable") {
  NavigationStack { CommunityFundingPage(balance: 0, unavailable: true) }
}
