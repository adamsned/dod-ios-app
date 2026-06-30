import Foundation
import Network

/// Connectivity observer. View models read ``isOnline`` for the offline
/// banner (CC-2, AC-1.6) and subscribe to ``changes`` for live updates.
///
/// Implemented as an `actor` so callers from any concurrency context can
/// read state safely.
public actor NetworkMonitor {

    public static let shared = NetworkMonitor()

    private let pathMonitor: NWPathMonitor
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    /// DUT-206: single ordered pipe for NWPath updates (see `start()`).
    private var pathContinuation: AsyncStream<Bool>.Continuation?
    private var drainTask: Task<Void, Never>?
    private(set) public var isOnline: Bool = true

    public init() {
        self.pathMonitor = NWPathMonitor()
    }

    /// Start observing connectivity. Idempotent.
    public func start() {
        guard pathMonitor.queue == nil else { return }
        let queue = DispatchQueue(label: "com.dutchovendaddy.networkmonitor")
        // DUT-206: feed path updates through ONE ordered AsyncStream rather than
        // spawning an unstructured Task per update (which can run out of order under
        // a burst and latch a stale isOnline). The handler runs on the serial
        // NWPathMonitor queue, so the stream preserves OS emission order.
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        pathContinuation = continuation
        pathMonitor.pathUpdateHandler = { path in
            continuation.yield(path.status == .satisfied)
        }
        drainTask = Task { [weak self] in
            for await isOnline in stream {
                await self?.handle(isOnline: isOnline)
            }
        }
        pathMonitor.start(queue: queue)
    }

    /// AsyncStream of connectivity changes. The first value emitted is the
    /// current state at subscription time.
    public func changes() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(isOnline)
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }

    private func handle(isOnline: Bool) {
        guard isOnline != self.isOnline else { return }
        self.isOnline = isOnline
        for continuation in continuations.values {
            continuation.yield(isOnline)
        }
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }

    deinit {
        pathMonitor.cancel()
        for continuation in continuations.values {
            continuation.finish()
        }
    }
}
