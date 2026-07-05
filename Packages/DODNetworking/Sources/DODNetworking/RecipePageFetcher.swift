import Foundation

/// Fetches the rendered HTML page for a recipe so the JSON-LD parser can
/// extract structured content (plan §3, CL-1).
public struct RecipePageFetcher: Sendable {

    let httpClient: HTTPClient

    public init(httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    /// Fetch the rendered HTML for a post URL.
    public func html(for url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"
        // DUT-388: bypass URLSession heuristic freshness + the Cloudflare edge cache
        // so re-opening a recipe after an edit parses fresh JSON-LD, not stale HTML
        // (WP sends only Last-Modified — the same trap DUT-355 fixed for REST GETs).
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        // DUT-578: no manual `Accept-Encoding: gzip` — URLSession negotiates +
        // transparently decompresses (this module has no gunzip).
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw WPClientError.httpStatus(response.statusCode)
        }
        guard
            let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        else {
            throw WPClientError.decoding(message: "Could not decode HTML as UTF-8 or Latin-1")
        }
        return html
    }
}
