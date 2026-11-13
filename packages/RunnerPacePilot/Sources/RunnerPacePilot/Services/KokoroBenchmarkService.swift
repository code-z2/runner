//
//  KokoroBenchmarkService.swift
//  RunnerPacePilot
//
//  Created by Peter on 13/11/2026.
//

import AudioCommon
import CoreML
import Foundation
import KokoroTTS
import ZIPFoundation

/// A bundled Kokoro checkpoint available for coaching.
///
/// Layout mirrors the HuggingFace repos (`kokoro_5s.mlmodelc/`, `voices/`,
/// vocabularies, dictionaries) so the SDK loads them offline with no changes.
public struct KokoroVariant: Sendable, Hashable {
  public let id: String
  public let displayName: String
  public let resourceDirectoryName: String
  /// Advertised weight size, for labels only.
  public let approxMegabytes: Int

  public init(id: String, displayName: String, resourceDirectoryName: String, approxMegabytes: Int)
  {
    self.id = id
    self.displayName = displayName
    self.resourceDirectoryName = resourceDirectoryName
    self.approxMegabytes = approxMegabytes
  }

  public static let fp16 = KokoroVariant(
    id: "fp16",
    displayName: "Kokoro FP16",
    resourceDirectoryName: "Kokoro-82M-CoreML",
    approxMegabytes: 325
  )
  public static let int8 = KokoroVariant(
    id: "int8",
    displayName: "Kokoro INT8",
    resourceDirectoryName: "Kokoro-82M-CoreML-INT8",
    approxMegabytes: 83
  )

  public static let all: [KokoroVariant] = [.fp16, .int8]
}

public enum KokoroBenchmarkError: Error, Sendable {
  case modelsDirectoryMissing(URL)
  case modelNotLoaded(KokoroVariant)
}

/// Loads bundled Kokoro checkpoints offline and synthesizes speech.
///
/// Each variant gets its own serial queue, so the blocking CoreML calls never
/// stall the Swift cooperative thread pool. Loads for the same variant are
/// serialized; the model stays loaded afterwards.
public actor KokoroBenchmarkService {
  private let modelsDirectory: URL
  private var boxes: [String: ModelBox] = [:]
  private var loading: [String: Task<ModelLoad, any Error>] = [:]

  public init(modelsDirectory: URL) {
    self.modelsDirectory = modelsDirectory
  }

  /// Unpacked model cache. Defaults to Application Support, so the bundle
  /// only ships the zips and each variant unpacks once on first use.
  public nonisolated static func defaultModelsDirectory() -> URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first?.appendingPathComponent("KokoroModels", isDirectory: true)
  }

  /// URL of the bundled zip for a variant, when the app ships `KokoroModels/`.
  public nonisolated static func bundledZip(
    for variant: KokoroVariant, in bundle: Bundle = .main
  ) -> URL? {
    bundle.url(forResource: variant.resourceDirectoryName, withExtension: "zip")
  }

  /// A load outcome: how long it took (nil when the model was already
  /// loaded) and which compute units it runs on.
  public struct ModelLoad: Sendable {
    public let seconds: Double?
    public let computeUnits: String
  }

  /// Compile and load the variant if needed.
  @discardableResult
  public func load(_ variant: KokoroVariant) async throws -> ModelLoad {
    try await load(variant, from: nil)
  }

  /// Unpack the bundled zip on first use, then load. Unpacking is skipped
  /// when the variant directory already holds a model.
  @discardableResult
  public func load(_ variant: KokoroVariant, from bundledZip: URL?) async throws -> ModelLoad {
    if let box = boxes[variant.id] {
      return ModelLoad(seconds: nil, computeUnits: box.computeUnits ?? "all")
    }
    if let pending = loading[variant.id] { return try await pending.value }
    let pending = Task {
      try await prepare(variant, from: bundledZip)
    }
    loading[variant.id] = pending
    defer { loading[variant.id] = nil }
    return try await pending.value
  }

  private func prepare(_ variant: KokoroVariant, from bundledZip: URL?) async throws -> ModelLoad {
    let directory = modelsDirectory.appendingPathComponent(
      variant.resourceDirectoryName, isDirectory: true)
    let box = ModelBox()
    let started = CFAbsoluteTimeGetCurrent()
    try await box.run { _ in
      let fileManager = FileManager.default
      let e2eURL = directory.appendingPathComponent("kokoro_5s.mlmodelc", isDirectory: true)
      if !fileManager.fileExists(atPath: e2eURL.path) {
        guard let bundledZip else {
          throw KokoroBenchmarkError.modelsDirectoryMissing(directory)
        }
        let staging = directory.deletingLastPathComponent()
          .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        try fileManager.unzipItem(at: bundledZip, to: staging)
        if fileManager.fileExists(atPath: directory.path) {
          _ = try fileManager.replaceItemAt(directory, withItemAt: staging)
        } else {
          try fileManager.moveItem(at: staging, to: directory)
        }
      }
    }
    let loaded = try await loadFromDirectory(variant, directory: directory, box: box)
    return ModelLoad(
      seconds: CFAbsoluteTimeGetCurrent() - started, computeUnits: loaded.units)
  }

  /// Compute units to try, in order. CPU only: the coach speaks from the
  /// background, where the GPU is unavailable, so Metal/ANE units are out.
  /// Pure CPU MIL execution also sidesteps the iOS 26 MPSGraph failure on
  /// this graph's transpose ops.
  static let unitFallbacks: [MLComputeUnits] = [.cpuOnly]

  /// Try each unit in turn, returning the first success. Throws the last
  /// error when every unit fails.
  static func firstSuccessful<T>(
    _ units: [MLComputeUnits],
    load: (MLComputeUnits) async throws -> T
  ) async throws -> (value: T, units: MLComputeUnits) {
    var lastError: Error?
    for units in units {
      do {
        return (try await load(units), units)
      } catch {
        lastError = error
      }
    }
    throw lastError!
  }

  private func loadFromDirectory(
    _ variant: KokoroVariant, directory: URL, box: ModelBox? = nil
  ) async throws -> (seconds: Double, units: String) {
    let box = box ?? ModelBox()
    let started = CFAbsoluteTimeGetCurrent()
    let units = try await box.run { confined in
      let loaded = try await Self.firstSuccessful(Self.unitFallbacks) { units in
        let model = try await KokoroTTSModel.fromPretrained(
          modelId: variant.resourceDirectoryName,
          cacheDir: directory,
          offlineMode: true,
          computeUnits: units,
          warmUp: false
        )
        // Trial prediction: device GPU/ANE programs compile lazily, so a
        // load that "succeeds" can still fail on first inference (seen on
        // iOS 26 MPSGraph). Only accept a unit that actually predicts.
        // This also warms the model, so the timed synthesis runs warm.
        _ = try model.synthesize(text: "hello", voice: KokoroTTSModel.defaultVoice)
        return model
      }
      confined.model = loaded.value
      confined.computeUnits = CoreMLComputeUnitsResolver.shortName(loaded.units)
      return loaded.units
    }
    boxes[variant.id] = box
    return (CFAbsoluteTimeGetCurrent() - started, CoreMLComputeUnitsResolver.shortName(units))
  }

  /// Synthesize text with an already-loaded variant.
  public func synthesize(
    _ variant: KokoroVariant,
    text: String,
    voice: String = KokoroTTSModel.defaultVoice
  ) async throws -> KokoroSynthesis {
    guard let box = boxes[variant.id] else {
      throw KokoroBenchmarkError.modelNotLoaded(variant)
    }
    let started = CFAbsoluteTimeGetCurrent()
    let samples = try await box.run { confined in
      guard let model = confined.model else {
        throw KokoroBenchmarkError.modelNotLoaded(variant)
      }
      return try model.synthesize(text: text, voice: voice)
    }
    return KokoroSynthesis(
      samples: samples,
      sampleRate: KokoroTTSModel.outputSampleRate,
      synthSeconds: CFAbsoluteTimeGetCurrent() - started
    )
  }

  /// Forget a loaded model, freeing its memory. The next run loads cold again.
  public func unload(_ variant: KokoroVariant) {
    boxes[variant.id] = nil
  }
}

/// Timed synthesis output without the load stage.
public struct KokoroSynthesis: Sendable {
  public let samples: [Float]
  public let sampleRate: Int
  public let synthSeconds: Double
}

/// Owns one `KokoroTTSModel` and runs every interaction with it on a private
/// serial queue. The model type is not `Sendable`; confining all access to
/// this queue is what makes the box safe to share.
private final class ModelBox: @unchecked Sendable {
  private let queue = DispatchQueue(
    label: "io.wades.ije.kokoro-model", qos: .userInitiated)
  var model: KokoroTTSModel?
  var computeUnits: String?

  /// Run `work` on the box queue and bridge the result back to the caller.
  /// The queue thread parks on a semaphore while Swift concurrency does the
  /// work, so the cooperative thread pool is never blocked.
  func run<T: Sendable>(_ work: @Sendable @escaping (ModelBox) async throws -> T) async throws -> T
  {
    try await withCheckedThrowingContinuation { continuation in
      queue.async {
        let holder = ResultHolder<T>()
        Task {
          do {
            holder.value = .success(try await work(self))
          } catch {
            holder.value = .failure(error)
          }
          holder.semaphore.signal()
        }
        holder.semaphore.wait()
        continuation.resume(with: holder.value ?? .failure(CocoaError(.userCancelled)))
      }
    }
  }
}

/// Mutable cell so a `Task` and a semaphore can rendezvous across the
/// queue boundary. Written once before `signal`, read once after `wait`.
private final class ResultHolder<T: Sendable>: @unchecked Sendable {
  let semaphore = DispatchSemaphore(value: 0)
  var value: Result<T, Error>?
}
