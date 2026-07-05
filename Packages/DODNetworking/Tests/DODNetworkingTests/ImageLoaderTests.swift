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
        await fake.stub(
            urlContaining: "big.jpg",
            with: { _ in
                // Simulate slow network.
                try await Task.sleep(nanoseconds: 50_000_000)
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
        await fake.stub(
            urlContaining: "cancel-race.jpg",
            with: { _ in
                // Slow enough that the creator is cancelled while the download
                // is still in flight, and a later caller can join it.
                try await Task.sleep(nanoseconds: 200_000_000)
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
        // Give A time to install the in-flight slot before cancelling it.
        try await Task.sleep(nanoseconds: 40_000_000)
        creator.cancel()

        // While the download is STILL running, caller C asks for the same URL.
        // The shared slot must have survived A's cancellation so C coalesces
        // onto the one live download rather than spawning a duplicate.
        let bytes = try await loader.data(for: url)
        #expect(bytes == payload)

        // The spy proves C did NOT spawn a second request.
        let captured = await fake.capturedRequests
        #expect(captured.count == 1, "Creator cancellation must not drop the shared in-flight entry")
    }
}
