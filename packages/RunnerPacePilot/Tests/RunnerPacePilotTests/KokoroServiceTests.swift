//
//  KokoroServiceTests.swift
//  RunnerPacePilotTests
//
//  Created by Peter on 13/11/2026.
//

import CoreML
import Foundation
import Testing

@testable import RunnerPacePilot

struct KokoroServiceTests {

  @Test(.enabled(if: ProcessInfo.processInfo.environment["KOKORO_INT8_ARCHIVE"] != nil))
  func concurrentColdLoadsShareTheArchiveAndSynthesizeRunCues() async throws {
    let archive = try #require(ProcessInfo.processInfo.environment["KOKORO_INT8_ARCHIVE"])
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let service = KokoroBenchmarkService(modelsDirectory: directory)
    let zip = URL(fileURLWithPath: archive)
    async let first = service.load(.int8, from: zip)
    async let second = service.load(.int8, from: zip)
    let loads = try await (first, second)
    #expect(loads.0.seconds != nil)
    #expect(loads.0.seconds == loads.1.seconds)
    for cue in [
      "Looks like you've stopped. Pause the run when you're ready.",
      "Kilometer one. Your average pace is six minutes and twenty seconds per kilometer.",
    ] {
      let speech = try await service.synthesize(.int8, text: cue)
      #expect(speech.samples.allSatisfy { $0.isFinite })
      #expect(speech.samples.contains { abs($0) > 0.0001 })
    }
  }

  @Test
  func variantsPointAtDifferentBundledDirectories() {
    #expect(KokoroVariant.fp16.resourceDirectoryName != KokoroVariant.int8.resourceDirectoryName)
    #expect(KokoroVariant.all.count == 2)
    #expect(KokoroVariant.int8.approxMegabytes < KokoroVariant.fp16.approxMegabytes)
  }

  @Test
  func fallbackTriesUnitsInOrder() async throws {
    var attempts: [MLComputeUnits] = []
    let loaded = try await KokoroBenchmarkService.firstSuccessful([.all, .cpuOnly]) { units in
      attempts.append(units)
      if units == .all { throw CocoaError(.fileReadNoSuchFile) }
      return 42
    }
    #expect(loaded.value == 42)
    #expect(loaded.units == .cpuOnly)
    #expect(attempts == [.all, .cpuOnly])
  }

  @Test
  func fallbackThrowsLastErrorWhenAllUnitsFail() async {
    do {
      _ = try await KokoroBenchmarkService.firstSuccessful([.all, .cpuOnly]) { _ in
        throw CocoaError(.fileReadNoSuchFile)
      }
      Issue.record("expected fallback to throw")
    } catch let error as CocoaError {
      #expect(error.code == .fileReadNoSuchFile)
    } catch {
      Issue.record("wrong error type: \(error)")
    }
  }

  @Test
  func missingModelsDirectoryThrows() async {
    let service = KokoroBenchmarkService(
      modelsDirectory: URL(fileURLWithPath: "/nonexistent-kokoro-models"))
    do {
      _ = try await service.load(.int8)
      Issue.record("expected modelsDirectoryMissing")
    } catch let error as KokoroBenchmarkError {
      guard case .modelsDirectoryMissing = error else {
        Issue.record("wrong error: \(error)")
        return
      }
    } catch {
      Issue.record("wrong error type: \(error)")
    }
  }

  @Test
  func synthesizeBeforeLoadThrows() async throws {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let service = KokoroBenchmarkService(modelsDirectory: dir)
    do {
      _ = try await service.synthesize(.fp16, text: "hello")
      Issue.record("expected modelNotLoaded")
    } catch let error as KokoroBenchmarkError {
      guard case .modelNotLoaded = error else {
        Issue.record("wrong error: \(error)")
        return
      }
    } catch {
      Issue.record("wrong error type: \(error)")
    }
  }
}
