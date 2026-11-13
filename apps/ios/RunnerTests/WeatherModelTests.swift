//
//  WeatherModelTests.swift
//  RunnerTests
//

import Foundation
import Testing

@testable import Runner

private actor FetchCounter {

  private var value = 0

  func increment() {
    value += 1
  }

  var count: Int {
    value
  }
}

@MainActor
struct WeatherModelTests {

  private func sunny(_ temp: Double = 20) -> RunWeather {
    RunWeather(
      temperature: Measurement(value: temp, unit: .celsius),
      condition: "Clear", symbolName: "sun.max")
  }

  @Test
  func fetchesWhenEmpty() async {
    let model = WeatherModel(fetch: { await self.sunny() })
    await model.refresh()
    #expect(model.weather?.condition == "Clear")
    #expect(model.fetchedAt != nil)
  }

  @Test
  func skipsFetchWhenFresh() async {
    let calls = FetchCounter()
    let now = Date()
    let model = WeatherModel(
      weather: sunny(), fetchedAt: now,
      fetch: {
        await calls.increment()
        return await self.sunny(25)
      },
      now: { now })
    await model.refresh()
    #expect(await calls.count == 0)
    #expect(model.weather?.temperature.value == 20)
  }

  @Test
  func refetchesWhenStale() async {
    let calls = FetchCounter()
    let now = Date()
    let model = WeatherModel(
      weather: sunny(), fetchedAt: now.addingTimeInterval(-16 * 60),
      fetch: {
        await calls.increment()
        return await self.sunny(25)
      },
      now: { now })
    await model.refresh()
    #expect(await calls.count == 1)
    #expect(model.weather?.temperature.value == 25)
  }

  @Test
  func concurrentRefreshFetchesOnce() async {
    let calls = FetchCounter()
    let model = WeatherModel(
      fetch: {
        await calls.increment()
        await Task.yield()
        return await self.sunny()
      })
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await model.refresh() }
      group.addTask { await model.refresh() }
    }
    #expect(await calls.count == 1)
    #expect(model.weather != nil)
  }

  @Test
  func failedFetchKeepsLastValue() async {
    let seededAt = Date()
    let model = WeatherModel(weather: sunny(18), fetchedAt: seededAt, fetch: { nil })
    await model.refresh()
    #expect(model.weather?.temperature.value == 18)
    #expect(model.fetchedAt == seededAt)
  }

  @Test
  func cancelledRefreshChangesNothing() async throws {
    let seededAt = Date()
    let staleAt = seededAt.addingTimeInterval(-16 * 60)
    let model = WeatherModel(
      weather: sunny(18), fetchedAt: staleAt,
      fetch: {
        try? await Task.sleep(for: .seconds(30))
        return await self.sunny(25)
      })
    let task = Task { await model.refresh() }
    try await Task.sleep(for: .milliseconds(50))
    task.cancel()
    await task.value
    #expect(model.weather?.temperature.value == 18)
    #expect(model.fetchedAt == staleAt)
  }
}
