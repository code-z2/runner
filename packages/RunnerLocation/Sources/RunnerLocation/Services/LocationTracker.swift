//
//  LocationTracker.swift
//  RunnerLocation
//
//  Created by Peter on 07/11/2026.
//

/// Owns one live location stream. Start and stop are synchronous,
/// transactional actor methods; the stream ends when stopped.
public actor LocationTracker {

    private let source: any LocationUpdateSource

    private var continuation: AsyncStream<LocationEvent>.Continuation?

    public init(source: some LocationUpdateSource) {
        self.source = source
    }

    public var isActive: Bool {
        continuation != nil
    }

    public func start() async throws -> AsyncStream<LocationEvent> {
        if continuation != nil {
            throw LocationError.alreadyActive
        }
        let (stream, continuation) = AsyncStream.makeStream(of: LocationEvent.self)
        self.continuation = continuation
        await source.start { event in
            continuation.yield(event)
        }
        return stream
    }

    public func stop() async {
        continuation?.finish()
        continuation = nil
        await source.stop()
    }
}
