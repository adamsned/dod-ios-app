import Foundation

/// Image-bytes loader with in-flight request coalescing. Two concurrent
/// callers asking for the same URL share a single network request.
///
/// Disk caching is intentionally *not* in this actor — the disk-cache layer
/// belongs to DODPersistence (T-073). This loader speaks bytes only.
///
/// Spec trace: plan §3, supports AC-1.3 (feed images) and AC-5.2 (offline
/// pre-download for saved recipes).
public actor ImageLoader {

    private let httpClient: HTTPClient
    private var inFlight: [URL: Task<Data, Error>] = [:]
    /// Monotonic token stamped on each in-flight entry so a download's tail
    /// clears ONLY its own slot and never a newer same-URL task (DUT-341).
    private var slotTokens: [URL: UInt64] = [:]
    private var nextToken: UInt64 = 0

    public init(httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    /// Fetch bytes for an image URL. Concurrent calls for the same URL
    /// share a single Task.
    public func data(for url: URL) async throws -> Data {
        if let existing = inFlight[url] {
            return try await existing.value
        }
        // DUT-580: the shared in-flight slot is cleared from the download's OWN
        // tail (`clearSlot`), NOT from the creating caller's `defer`. The old
        // `defer` fired on ANY scope exit — including the `CancellationError`
        // thrown from `await task.value` when the CREATING caller is cancelled
        // (its cell scrolls off / view is dismissed). Because the download runs
        // in its own `Task`, it kept going after that cancellation, so clearing
        // the slot in the caller's `defer` dropped a still-live shared entry: a
        // later same-URL caller then saw an empty slot and spawned a SECOND
        // request for bytes already in flight — the exact coalescing loss this
        // actor exists to prevent (DUT-213/516). `Task.detached` also severs
        // cancellation inheritance so a subscriber's cancellation can't reach
        // in and cancel the shared download. A monotonic `token` keeps the
        // identity-checked cleanup (DUT-341): a download's tail clears only its
        // own slot, never a newer same-URL task that has since replaced it.
        let token = nextToken
        nextToken &+= 1
        let task = Task<Data, Error>.detached { [httpClient, self] in
            defer { Task { await self.clearSlot(for: url, token: token) } }
            var request = URLRequest(url: url, timeoutInterval: 30)
            request.httpMethod = "GET"
            let (data, response) = try await httpClient.data(for: request)
            guard (200..<300).contains(response.statusCode) else {
                throw WPClientError.httpStatus(response.statusCode)
            }
            return data
        }
        inFlight[url] = task
        slotTokens[url] = token
        return try await task.value
    }

    /// Actor-isolated slot removal invoked from a download Task's own tail when
    /// it finishes (success, failure, or the download's own cancellation) —
    /// NOT from any subscriber's cancellation. Token-checked so a newer
    /// same-URL download that has already replaced this slot is never clobbered
    /// (DUT-341). Detaching cleanup from the caller means one subscriber
    /// cancelling can't evict the shared entry out from under the others
    /// (DUT-580).
    private func clearSlot(for url: URL, token: UInt64) {
        guard slotTokens[url] == token else { return }
        inFlight[url] = nil
        slotTokens[url] = nil
    }

    /// Test/diagnostic introspection.
    public var inFlightCount: Int { inFlight.count }
}
