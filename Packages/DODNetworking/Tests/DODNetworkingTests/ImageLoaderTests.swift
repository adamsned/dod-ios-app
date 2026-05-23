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
}
