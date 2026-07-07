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
    /// DUT-522: seeded to the real `currentPath.status` inside ``start()`` (see
    /// below). It stays `true` only until `start()` runs; the initial `true` is
    /// never observed by callers because `start()` is invoked at launch before
    /// any `await isOnline` read. `true` (rather than `false`) is the safe
    /// pre-start default: it avoids a false-positive offline banner in the
    /// sub-millisecond window before `start()` seeds the truth.
    private(set) public var isOnline: Bool = true

    /// Test seam (hardens the flaky DUT-522 seed test): overrides the initial
    /// `start()` seed status so a test can assert the "seed from the real path,
    /// not the hardcoded default" contract deterministically — instead of racing
    /// two live `NWPathMonitor`s against the CI host's actual connectivity. `nil`
    /// (production) reads the real started monitor's `currentPath` as before.
    private let seedStatusOverride: (@Sendable () -> Bool)?

    public init(seedStatusOverride: (@Sendable () -> Bool)? = nil) {
        self.pathMonitor = NWPathMonitor()
        self.seedStatusOverride = seedStatusOverride
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
        // DUT-522: `NWPathMonitor` only delivers `pathUpdateHandler` on a later
        // async hop, so before this line `isOnline` is still the pre-start
        // default (`true`) and an `await isOnline` in the launch window would
        // mis-read a genuinely offline device as online (e.g. Airplane Mode →
        // empty state rendered as "loaded, nothing here"). `currentPath` is
        // populated synchronously once `start(queue:)` has run, so seed the real
        // state now. Routed through `handle(_:)` so the DUT-206 de-dup holds and
        // any subsequent first `pathUpdateHandler` carrying the SAME status is
        // coalesced — while a DIFFERENT later status still fires a notification.
        handle(isOnline: seedStatusOverride?() ?? (pathMonitor.currentPath.status == .satisfied))
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
