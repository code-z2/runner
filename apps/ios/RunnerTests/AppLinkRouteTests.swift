//
//  AppLinkRouteTests.swift
//  RunnerTests
//
//  Created by Peter on 09/11/2026.
//

import Foundation
import Testing

@testable import Runner

struct AppLinkRouteTests {

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
