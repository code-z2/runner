//
//  CadenceTracker.swift
//  RunnerCadence
//
//  Created by Peter on 07/11/2026.
//

/// Owns one live cadence stream. Start and stop are synchronous,
/// transactional actor methods; the stream ends when stopped.
public actor CadenceTracker {

  private let source: any CadenceUpdateSource

  private var continuation: AsyncStream<CadenceEvent>.Continuation?

  public init(source: some CadenceUpdateSource) {
    self.source = source
  }

  public var isActive: Bool {
    continuation != nil
  }

  public func start() async throws -> AsyncStream<CadenceEvent> {
    if continuation != nil {
      throw CadenceError.alreadyActive
    }
    let (stream, continuation) = AsyncStream.makeStream(of: CadenceEvent.self)
    self.continuation = continuation
    do {
      try await source.start { event in
        continuation.yield(event)
      }
      return stream
    } catch {
      continuation.finish()
      self.continuation = nil
      throw error
    }
  }

  public func stop() async {
    continuation?.finish()
    continuation = nil
    await source.stop()
  }
}
