//
//  AppLinkRouteTests.swift
//  RunnerTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import RunnerGateway
import Testing

@testable import Runner

struct AppLinkRouteTests {

  @Test
  func onlyAnUnbeatenGoalBlocksAnotherLock() {
    let beaten = GoalOverview.UnlockedGoal(
      id: UUID(),
      goal: GoalDraft(distance: .init(value: 5, unit: .kilometers), minutes: 25, amount: 10),
      returnChain: "Base", returnAddress: "0x1234…7890")
    var overview = GoalOverview(unlocked: [beaten])
    let draft = GoalDraft()

    #expect(overview.canLockGoal)
    overview.active = draft
    #expect(!overview.canLockGoal)
    #expect(overview.active == draft)
    #expect(overview.unlocked == [beaten])
  }

  @Test
  func aProvenLockedGoalIsShownReadyToWithdraw() {
    let id = UUID()
    let record = GoalRecord(
      id: id, state: "locked", distanceM: 1_000, maxSeconds: 2_100, amount: "5000000",
      originAsset: "nep141:base-0xabc.omft.near", returnAddress: "0x1", lockID: "0",
      lockedAt: 1_800_000_000)

    let unproven = GoalOverview(records: [record])
    #expect(unproven.active != nil)
    #expect(unproven.unlocked.isEmpty)

    let proven = GoalOverview(records: [record], provenGoal: id)
    #expect(proven.active == nil)
    #expect(proven.unlocked.map(\.id) == [id])
    #expect(proven.unlocked.first?.canWithdraw == true)
    #expect(proven.unlocked.first?.returnChain == "Base")
  }

  @Test
  func goalProgressCountsDistanceThenTheTimeLimit() {
    let goal = GoalDraft(distance: .init(value: 1, unit: .kilometers), minutes: 35, amount: 5)
    #expect(goal.progress(meters: 500, seconds: 300) == 0.5)
    #expect(goal.progress(meters: 1_000, seconds: 900) == 1)
    #expect(goal.progress(meters: 1_000, seconds: 4_200) == 0.5)
  }

  @Test
  func bestAttemptCountsOnlyRunsSinceTheLockAndCarriesTheUnlockNote() {
    let lockedAt = Date(timeIntervalSince1970: 1_800_000_000)
    var overview = GoalOverview(
      active: GoalDraft(distance: .init(value: 1, unit: .kilometers), minutes: 35, amount: 5))
    overview.lockedAt = lockedAt
    let runs = [
      RunSummary(id: UUID(), distanceMeters: 5_000, elapsed: 1_500, date: lockedAt - 60),
      RunSummary(id: UUID(), distanceMeters: 600, elapsed: 300, date: lockedAt + 60),
      RunSummary(id: UUID(), distanceMeters: 1_020, elapsed: 872, date: lockedAt + 600),
    ]

    let shown = overview.withAttempts(runs, note: "Run not verified: x")
    #expect(shown.progress == 1)
    #expect(shown.bestAttempt == "Best try: 1.02 km in 14:32\nRun not verified: x")
    #expect(overview.withAttempts([], note: nil).bestAttempt == nil)
  }

  @MainActor
  @Test
  func stackCannotPopLiveButCanPopCompletedSummary() {
    let navigation = HomeNavigation()
    let live = HomeDestination.live(distanceKilometers: nil)
    navigation.open(live)
    navigation.updatePathFromNavigationStack([])
    #expect(navigation.path == [live])

    let summary = RunSummary(id: UUID(), distanceMeters: nil, elapsed: 60, date: .now)
    navigation.path = [.summary(summary)]
    navigation.updatePathFromNavigationStack([])
    #expect(navigation.path.isEmpty)
  }

  private var host: String { AppConstants.associatedDomain }

  private func route(_ string: String) -> AppLinkRoute? {
    AppLinkRoute(url: URL(string: string)!, host: host)
  }

  @Test
  func launchAndHomeResolve() {
    #expect(route("https://ije.wades.io/launch") == .launch)
    #expect(route("https://ije.wades.io/home") == .home)
    #expect(route("https://ije.wades.io/launch")?.route == .launch)
    #expect(route("https://ije.wades.io/home")?.route == .home)
  }

  @Test
  func nonRoutesStayNil() {
    #expect(route("https://ije.wades.io/auth/callback?code=c&state=s") == nil)
    #expect(route("https://ije.wades.io/other") == nil)
    #expect(route("http://ije.wades.io/home") == nil)
    #expect(route("https://evil.example/home") == nil)
  }
}
