import RunnerUI
import SwiftUI

struct GoalsPage: View {
  let overview: GoalOverview
  var availability: GoalsViewModel.Availability = .ready
  var withdrawing: UUID?
  var withdrawLabel: LocalizedStringKey = "Requesting withdrawal…"
  var onOpenDeposit: (GoalOverview.Deposit) -> Void = { _ in }
  let onWithdraw: (GoalOverview.UnlockedGoal) -> Void

  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        Text("Goals")
          .runnerText(.titleLarge)
          .accessibilityAddTraits(.isHeader)

        if let pending = overview.pending {
          pendingCard(pending)
        }

        if let goal = overview.active {
          activeCard(goal)
        } else if overview.pending == nil, availability == .ready {
          VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Your next goal")
              .runnerText(.title)
            Text("Choose a distance and finish time. Beat your goal to unlock what you put in.")
              .runnerText(.body)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(Theme.Spacing.lg)
          .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }

        if availability == .loading {
          loadingCard
        } else if availability == .unavailable {
          Text("Goal status is unavailable. Pull to refresh before moving funds.")
            .runnerText(.footnote)
            .foregroundStyle(Theme.Colors.foregroundSecondary)
        }

        ForEach(overview.unlocked) { item in
          VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(item.isWithdrawing ? "Withdrawal in progress" : "Ready to withdraw")
              .runnerText(.eyebrow)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
            Text(item.goal.amountLabel).runnerText(.metricLarge)
            Text(item.goal.targetLabel).runnerText(.footnote)
            Text("Returns to \(item.returnAddress) on \(item.returnChain)")
              .runnerText(.footnote)
              .foregroundStyle(Theme.Colors.foregroundSecondary)
            if item.canWithdraw {
              Button(withdrawing == item.id ? withdrawLabel : "Withdraw") {
                onWithdraw(item)
              }
              .buttonStyle(.pill(.secondary, compact: true))
              .disabled(availability != .ready || withdrawing != nil)
              .accessibilityHint("Returns the funds to the address shown on this goal")
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(Theme.Spacing.lg)
          .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, Theme.Spacing.screenInset)
      .padding(.vertical, Theme.Spacing.lg)
    }
    .foregroundStyle(Theme.Colors.foreground)
    .background(Theme.Colors.background.ignoresSafeArea())
  }

  /// Placeholder in the shape of a goal card while the first load runs.
  private var loadingCard: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      Text("On a goal").runnerText(.eyebrow)
      Text("$25.00").runnerText(.metricLarge)
      Divider()
      Text("10 km under 55:00").runnerText(.titleSmall)
      Text("Beat this goal to lock another.").runnerText(.footnote)
    }
    .redacted(reason: .placeholder)
    .phaseAnimator(reduceMotion ? [1.0] : [1.0, 0.5]) { card, opacity in
      card.opacity(opacity)
    } animation: { _ in
      .easeInOut(duration: 0.9)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Theme.Spacing.lg)
    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Loading goals")
  }

  private func pendingCard(_ pending: GoalOverview.PendingGoal) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      Text("Awaiting deposit")
        .runnerText(.eyebrow)
        .foregroundStyle(Theme.Colors.primary)
      Text(pending.goal.amountLabel).runnerText(.metricLarge)
      Text(pending.goal.targetLabel).runnerText(.footnote)
      Text("Your goal locks after your deposit is confirmed.")
        .runnerText(.footnote)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
      if availability == .ready {
        if let deposit = pending.deposit {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            if deposit.isPayable(at: context.date) {
              Button("View deposit details") { onOpenDeposit(deposit) }
                .buttonStyle(.pill(.secondary, compact: true))
            } else {
              Text("Deposit instructions expired. Pull to refresh the status.")
                .runnerText(.footnote)
            }
          }
        } else {
          Text("Deposit details are unavailable. Pull to refresh the status.")
            .runnerText(.footnote)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Theme.Spacing.lg)
    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
  }

  private func activeCard(_ goal: GoalDraft) -> some View {
    let shape = RoundedRectangle(cornerRadius: Theme.Radius.card)
    return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      Text("On a goal")
        .runnerText(.eyebrow)
        .foregroundStyle(Theme.Colors.primary)
      Text(goal.amountLabel).runnerText(.metricLarge)
      Divider()
      Text(goal.targetLabel).runnerText(.titleSmall)
      ProgressView(value: overview.progress)
        .tint(Theme.Colors.primary)
        .accessibilityLabel("Goal progress")
      Text(overview.bestAttempt ?? "No attempts yet")
        .runnerText(.footnote)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
      Text("Beat this goal to lock another.")
        .runnerText(.footnote)
        .foregroundStyle(Theme.Colors.foregroundSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Theme.Spacing.lg)
    .background(Theme.Colors.surface, in: shape)
    .overlay { shape.strokeBorder(Theme.Colors.primary, lineWidth: Theme.Sizing.hairline) }
  }
}

struct GoalsNavigation: View {
  let model: GoalsViewModel
  let service: GoalService?
  var runs: [RunSummary] = []
  @Binding var path: [GoalDestination]

  @State
  private var goalDeposit: GoalOverview.Deposit?

  @State
  private var requestedWithdrawal: GoalOverview.UnlockedGoal?

  @Environment(\.scenePhase)
  private var scenePhase

  var body: some View {
    NavigationStack(path: $path) {
      GoalsPage(
        overview: model.overview.withAttempts(runs, note: model.unlockNote),
        availability: model.availability,
        withdrawing: model.withdrawing, withdrawLabel: LocalizedStringKey(model.withdrawLabel),
        onOpenDeposit: { goalDeposit = $0 },
        onWithdraw: { requestedWithdrawal = $0 }
      )
      .refreshable { await model.refresh(using: service) }
      .task(id: scenePhase == .active && path.isEmpty) {
        if scenePhase == .active, path.isEmpty { await model.refresh(using: service) }
      }
      .task(id: scenePhase == .active && model.isDelivering) {
        // 1Click is delivering a payout: keep the state current until it lands.
        while scenePhase == .active, model.isDelivering, !Task.isCancelled {
          try? await Task.sleep(for: .seconds(15))
          guard !Task.isCancelled else { return }
          await model.refresh(using: service)
        }
      }
      .sheet(item: $goalDeposit) { deposit in
        IntentDepositSheet(
          heading: "Goal deposit", amount: deposit.amount, asset: deposit.asset,
          network: deposit.network, address: deposit.address, memo: deposit.memo,
          deadline: deposit.deadline,
          onDone: {
            goalDeposit = nil
            Task { await model.refresh(using: service) }
          })
      }
      .alert(
        "Withdraw funds?",
        isPresented: Binding(
          get: { requestedWithdrawal != nil },
          set: { if !$0 { requestedWithdrawal = nil } }),
        presenting: requestedWithdrawal
      ) { item in
        Button("Withdraw") { Task { await model.withdraw(item, using: service) } }
        Button("Cancel", role: .cancel) {}
      } message: { item in
        Text("Send your unlocked funds to \(item.returnAddress) on \(item.returnChain)?")
      }
      .alert(
        "Withdrawal status",
        isPresented: Binding(
          get: { model.withdrawalError != nil },
          set: { if !$0 { model.dismissWithdrawalError() } }),
        presenting: model.withdrawalError
      ) { _ in
        Button("OK", role: .cancel) {}
      } message: { error in
        switch error {
        case .unavailable:
          Text("Goal withdrawals are temporarily paused.")
        case .statusUnconfirmed:
          Text("Check the withdrawal status before trying again.")
        }
      }
      .navigationDestination(for: GoalDestination.self) { destination in
        switch destination {
        case .lock:
          LockGoalPage { draft in
            if model.canStartFunding {
              path.append(.funding(draft, requestID: UUID()))
            }
          }
        case .funding(let draft, let requestID):
          GoalFundingPage(
            draft: draft, requestID: requestID, service: service,
            onReturnToGoals: { path.removeAll() })
        }
      }
    }
  }
}

#Preview("Loading") {
  GoalsPage(overview: GoalOverview(), availability: .loading, onWithdraw: { _ in })
}

#Preview("Unavailable") {
  GoalsPage(overview: GoalOverview(), availability: .unavailable, onWithdraw: { _ in })
}

#Preview("No goal") {
  GoalsPage(overview: GoalOverview(), onWithdraw: { _ in })
}

#Preview("Awaiting deposit") {
  let goal = GoalDraft()
  GoalsPage(
    overview: GoalOverview(
      pending: .init(
        goal: goal,
        deposit: .init(
          id: UUID(), goal: goal, amount: "25.08", asset: "USDC", network: "Base",
          address: "0x71c4b9a0e83dPREVIEWa5526f0c92c7a41e09d", memo: nil,
          deadline: .now.addingTimeInterval(300)))),
    onWithdraw: { _ in })
}

#Preview("Unbeaten goal") {
  GoalsPage(
    overview: GoalOverview(
      active: GoalDraft(), bestAttempt: "Best try: 9.1 km in 50:12",
      progress: 0.91), onWithdraw: { _ in })
}

#Preview("On a goal + ready to withdraw") {
  GoalsWithdrawalPreview(active: GoalDraft())
}

#Preview("No goal + ready to withdraw") {
  GoalsWithdrawalPreview(active: nil)
}

private struct GoalsWithdrawalPreview: View {
  @State private var overview: GoalOverview
  @State private var withdrew = false

  init(active: GoalDraft?) {
    _overview = State(
      initialValue: GoalOverview(
        active: active,
        bestAttempt: active.map { _ in "Best try: 9.1 km in 50:12" },
        progress: active == nil ? 0 : 0.91,
        unlocked: [
          .init(
            id: UUID(),
            goal: GoalDraft(distance: .init(value: 5, unit: .kilometers), minutes: 25, amount: 10),
            returnChain: "Base", returnAddress: "0x1234…7890")
        ]))
  }

  var body: some View {
    NavigationStack {
      GoalsPage(overview: overview) { item in
        overview.unlocked.removeAll { $0.id == item.id }
        withdrew = true
      }
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: Theme.Spacing.sm) {
          if withdrew {
            Text("Sample withdrawal complete").runnerText(.footnote)
          }
          if overview.canLockGoal {
            NavigationLink {
              LockGoalPage(onContinue: { _ in })
            } label: {
              Text("Lock a goal")
            }
            .buttonStyle(.pill())
          }
        }
        .padding(.horizontal, Theme.Spacing.screenInset)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
      }
    }
  }
}
