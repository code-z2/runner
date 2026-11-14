import RunnerEscrow
import RunnerNear
import RunnerUI
import SwiftUI

struct GoalFundingPage: View {
  let draft: GoalDraft
  var requestID = UUID()
  var service: GoalService?
  var onReturnToGoals: () -> Void = {}
  var onConfirmSample: (() -> Void)?

  @State private var chain = FundingNetwork.base
  @State private var returnAddress = ""
  @State private var addressInput = ""
  @State private var editingReturnAddress = false
  @State private var showingDeposit = false
  @State private var liveDeposit: GoalOverview.Deposit?
  @State private var requestingQuote = false
  @State private var submittedAddress: String?
  @State private var fundingError: FundingError?

  private enum FundingError: String, Identifiable {
    case unavailable, invalidDraft, invalidAddress, quoteFailed

    var id: Self { self }

    func message(network: String) -> LocalizedStringKey {
      switch self {
      case .unavailable:
        "Goal funding is temporarily paused."
      case .invalidDraft:
        "Use a goal from 1 to 100 km and an amount of at least $5."
      case .invalidAddress:
        "Enter a valid \(network) wallet address for USDC."
      case .quoteFailed:
        "We couldn’t confirm your quote. Retry to check the same request."
      }
    }
  }

  private var isSample: Bool { onConfirmSample != nil }

  private static let maxUSD = Decimal(99_999_999) / 100

  private var sourceAmount: String {
    draft.amount.formatted(.number.precision(.fractionLength(0...2)))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          Text("Your goal escrow")
            .runnerText(.eyebrow)
            .foregroundStyle(Theme.Colors.primary)
          Text(draft.amountLabel)
            .runnerText(.metricLarge)
          Text(draft.targetLabel)
            .runnerText(.titleSmall)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text(isSample ? "Choose a source network" : "Source network")
            .runnerText(.eyebrow)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
            .accessibilityAddTraits(.isHeader)
          ViewThatFits(in: .horizontal) {
            chainRow([.base, .ethereum, .solana, .arbitrum])
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
              chainRow([.base, .ethereum])
              chainRow([.solana, .arbitrum])
            }
          }
          chainRow([.bnb, .polygon, .sui])
        }
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text(isSample ? "Amount" : "Target escrow amount")
            .runnerText(.eyebrow)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
          HStack(alignment: .firstTextBaseline) {
            Text(isSample ? sourceAmount : draft.amount.formatted(.number))
              .runnerText(.metricLarge)
              .lineLimit(1)
              .minimumScaleFactor(0.5)
            Spacer()
            Text("USDC")
              .runnerText(.footnote)
              .padding(.horizontal, Theme.Spacing.md)
              .padding(.vertical, Theme.Spacing.xs)
              .background(Theme.Colors.secondary, in: Capsule())
          }
          .padding(Theme.Spacing.md)
          .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
          .accessibilityElement(children: .combine)
        }
        IntentQuoteCard(
          heading: isSample ? "Sample quote" : "Funding details",
          recipientLabel: "Goal escrow receives",
          sends: isSample
            ? "\(sourceAmount) USDC on \(chain.title)"
            : String(localized: "Quoted in USDC on \(chain.title)"),
          receives: "\(draft.amount.formatted(.number)) USDC on NEAR",
          returnAddress: returnAddress,
          canEditReturnAddress: submittedAddress == nil,
          onEditReturnAddress: editReturnAddress)
        Text(
          isSample
            ? "Sample only. No funds are moved."
            : "Your goal locks after the deposit is confirmed."
        )
        .runnerText(.footnote)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
      }
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.lg)
    }
    .safeAreaInset(edge: .bottom) {
      Button(
        requestingQuote ? "Getting quote…" : isSample ? "Lock goal" : "Get deposit quote",
        action: requestQuote
      )
      .buttonStyle(.pill())
      .disabled(returnAddress.isEmpty || requestingQuote || (!isSample && service == nil))
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.sm)
      .background(Theme.Colors.background)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
    .navigationTitle("Fund your goal")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(requestingQuote)
    .onChange(of: chain, initial: true) {
      returnAddress = UserDefaults.standard.string(forKey: chain.returnAddressKey) ?? ""
    }
    .alert("Return address", isPresented: $editingReturnAddress) {
      TextField("Wallet address", text: $addressInput)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
      Button("Cancel", role: .cancel) {}
      Button("Save") {
        returnAddress = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if returnAddress.isEmpty {
          UserDefaults.standard.removeObject(forKey: chain.returnAddressKey)
        }
      }
    } message: {
      Text("Enter a wallet address for USDC on \(chain.title).")
    }
    .sheet(isPresented: $showingDeposit) {
      IntentDepositSheet(
        heading: "Sample deposit", amount: sourceAmount, asset: "USDC",
        network: chain.title,
        address: "Example deposit address",
        onDone: {
          UserDefaults.standard.set(returnAddress, forKey: chain.returnAddressKey)
          showingDeposit = false
          onConfirmSample?()
        })
    }
    .sheet(item: $liveDeposit) { deposit in
      IntentDepositSheet(
        heading: "Goal deposit", amount: deposit.amount, asset: deposit.asset,
        network: deposit.network, address: deposit.address, memo: deposit.memo,
        deadline: deposit.deadline,
        onDone: {
          liveDeposit = nil
          onReturnToGoals()
        })
    }
    .alert(item: $fundingError) { error in
      Alert(title: Text("Goal funding"), message: Text(error.message(network: chain.title)))
    }
  }

  private func requestQuote() {
    if isSample {
      showingDeposit = true
      return
    }
    guard let service, !requestingQuote else { return }
    let meters = draft.distance.converted(to: .meters).value.rounded()
    var usd = draft.amount
    var atomic = Decimal.zero
    guard let distance = UInt32(exactly: meters), (1_000...100_000).contains(distance),
      draft.amount >= 5, draft.amount <= Self.maxUSD,
      NSDecimalMultiplyByPowerOf10(&atomic, &usd, 6, .plain) == .noError
    else {
      fundingError = .invalidDraft
      return
    }
    let address = submittedAddress ?? returnAddress
    let source = chain
    guard source.isValid(returnAddress: address) else {
      fundingError = .invalidAddress
      return
    }
    submittedAddress = address
    requestingQuote = true
    Task {
      defer { requestingQuote = false }
      do {
        let quote = try await service.quote(
          goalID: requestID, goal: EscrowGoal(distanceM: distance, maxSeconds: draft.maxSeconds),
          amount: NSDecimalNumber(decimal: atomic).stringValue, network: source,
          returnAddress: address)
        UserDefaults.standard.set(address, forKey: source.returnAddressKey)
        if let deposit = GoalOverview.Deposit(
          id: requestID, goal: draft, network: source, quote: quote),
          deposit.isPayable()
        {
          liveDeposit = deposit
        } else {
          fundingError = .quoteFailed
        }
      } catch NearError.relayer(let status, _) where status == 503 {
        submittedAddress = nil
        fundingError = .unavailable
      } catch NearError.relayer(let status, _) where status == 422 || status == 400 {
        submittedAddress = nil
        fundingError = .invalidDraft
      } catch {
        fundingError = .quoteFailed
      }
    }
  }

  private func editReturnAddress() {
    addressInput = returnAddress
    editingReturnAddress = true
  }

  private func chainRow(_ options: [FundingNetwork]) -> some View {
    HStack(spacing: Theme.Spacing.xs) {
      ForEach(options) { option in
        RunDistanceChip(title: LocalizedStringKey(option.title), selected: chain == option) {
          chain = option
        }
        .disabled(submittedAddress != nil)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
  }
}

#Preview("Goal funding") {
  NavigationStack { GoalFundingPage(draft: GoalDraft(), onConfirmSample: {}) }
}
