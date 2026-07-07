import Foundation
import Testing

@testable import DODNetworking

@Suite("ImageLoader") struct ImageLoaderTests {

    @Test func returnsBytesForSuccessResponse() async throws {
        let fake = FakeHTTPClient()
        let payload = Data([0x89, 0x50, 0x4E, 0x47])  // PNG magic
        let url = URL(string: "https://example.com/img.png") ?? URL(filePath: "/")
        await fake.stub(
            urlContaining: "img.png",
            with: { _ in
                let response =
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: "HTTP/1.1",
                        headerFields: nil
                    ) ?? HTTPURLResponse()
                return (payload, response)
            }
        )
        let loader = ImageLoader(httpClient: fake)
        let data = try await loader.data(for: url)
        #expect(data == payload)
    }

    @Test func httpErrorThrows() async throws {
        let fake = FakeHTTPClient()
        let url = URL(string: "https://example.com/missing.png") ?? URL(filePath: "/")
        await fake.stub(
            urlContaining: "missing.png",
            with: { _ in
                let response =
                    HTTPURLResponse(
                        url: url,
                        statusCode: 404,
                        httpVersion: "HTTP/1.1",
                        headerFields: nil
                    ) ?? HTTPURLResponse()
                return (Data(), response)
            }
        )
        let loader = ImageLoader(httpClient: fake)
        await #expect(throws: WPClientError.httpStatus(404)) {
            _ = try await loader.data(for: url)
        }
    }

    @Test func concurrentCallsForSameURLCoalesceIntoOneRequest() async throws {
        let fake = FakeHTTPClient()
        let url = URL(string: "https://example.com/big.jpg") ?? URL(filePath: "/")
        let payload = Data(repeating: 0xAB, count: 1024)
        // A gate replaces the old fixed 50ms "slow network" sleep: the handler
        // holds the shared download open until the test has confirmed the one
        // request is in flight, so the coalescing window is deterministic on a
        // slow/loaded CI box instead of racing a wall-clock timer (DUT-700).
        let gate = TestGate()
        await fake.stub(
            urlContaining: "big.jpg",
            with: { _ in
                await gate.wait()
                let response =
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: "HTTP/1.1",
                        headerFields: nil
                    ) ?? HTTPURLResponse()
                return (payload, response)
            }
        )
        let loader = ImageLoader(httpClient: fake)

        async let first = loader.data(for: url)
        async let second = loader.data(for: url)
        async let third = loader.data(for: url)

        // Wait until the single shared request is actually in flight. The creator
        // installed the in-flight slot and entered the (gated) handler; the two
        // later callers coalesced onto that live slot on the free loader actor
        // during this poll's await windows (the slot can't be cleared while the
        // gate holds the download open). Only then release it.
        await waitUntil { await fake.capturedRequests.count == 1 }
        await gate.open()

        let (one, two, three) = try await (first, second, third)
        #expect(one == payload && two == payload && three == payload)

        let captured = await fake.capturedRequests
        #expect(captured.count == 1, "Coalescing should yield exactly one network call")
    }

    /// DUT-580: when the CREATING caller is cancelled mid-flight (cell scrolls
    /// off / view dismissed), its cancellation must NOT evict the shared
    /// in-flight slot. Previously the creator's `defer` cleared the slot on the
    /// thrown `CancellationError` even though the unstructured download Task
    /// kept running, so a later caller for the same URL spawned a duplicate
    /// request. With cleanup tied to the Task's own completion, the second
    /// caller still coalesces onto the one live download.
    @Test func laterCallerSharesDownloadWhenCreatorIsCancelled() async throws {
        let fake = FakeHTTPClient()
        let url = try #require(URL(string: "https://example.com/cancel-race.jpg"))
        let payload = Data(repeating: 0xCD, count: 512)
        // A gate replaces the old fixed 200ms "slow network" sleep: the handler
        // holds the shared download open until the test releases it, so the
        // creator is deterministically still in flight both when it is cancelled
        // and when the later caller joins — no wall-clock guessing (DUT-700).
        let gate = TestGate()
        await fake.stub(
            urlContaining: "cancel-race.jpg",
            with: { _ in
                await gate.wait()
                let response =
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: "HTTP/1.1",
                        headerFields: nil
                    ) ?? HTTPURLResponse()
                return (payload, response)
            }
        )
        let loader = ImageLoader(httpClient: fake)

        // Caller A creates the shared download, then is cancelled while the
        // download is still in flight (cell scrolled off / view dismissed).
        // Crucially we do NOT await A here — awaiting its `.value` would block
        // until the download finishes, hiding the mid-flight race we're testing.
        let creator = Task { try await loader.data(for: url) }
        // Wait until A's request is actually in flight before cancelling it,
        // instead of assuming a fixed sleep installed the slot (the old flake).
        await waitUntil { await fake.capturedRequests.count == 1 }
        creator.cancel()

        // While the download is STILL gated open, caller C asks for the same URL.
        // The shared slot must have survived A's cancellation so C coalesces
        // onto the one live download rather than spawning a duplicate. Yield so
        // C attaches to the live slot BEFORE we release the download (the gate is
        // still closed, so the slot cannot be cleared out from under C).
        async let cBytes = loader.data(for: url)
        await Task.yield()
        await gate.open()
        let bytes = try await cBytes
        #expect(bytes == payload)

        // The spy proves C did NOT spawn a second request.
        let captured = await fake.capturedRequests
        #expect(captured.count == 1, "Creator cancellation must not drop the shared in-flight entry")
    }

    /// Poll until an async `condition` holds or a short deadline passes — the
    /// deterministic replacement for the fixed sleeps these tests used to race
    /// on (DUT-700). The condition is async so it can read the `FakeHTTPClient`
    /// actor's `capturedRequests`.
    private func waitUntil(
        _ condition: @Sendable () async -> Bool,
        timeout: TimeInterval = 2.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while await !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

/// Minimal async gate: the stubbed handler `await`s it so a download stays in
/// flight until the test opens it. Lets the coalescing/cancellation tests pin
/// their contract without a wall-clock sleep (DUT-700).
private actor TestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}
