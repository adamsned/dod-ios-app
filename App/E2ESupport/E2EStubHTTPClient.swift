import DODNetworking
import Foundation

/// T-610 — the hermetic E2E network stub. When the host launches in
/// `-DOD_E2E_MODE=1`, `AppDependencies` injects this in place of
/// ``URLSessionHTTPClient`` into EVERY network client (`WPRestClient`,
/// `RecipePageFetcher`, `ImageLoader`, `WPCommentsClient`, `WPRMRatingsClient`).
/// Because all five share the one ``HTTPClient`` seam, the whole app then runs
/// against canned, deterministic responses — exercising the REAL parsers, view
/// models, and (in-memory) persistence — so the L5 journeys never touch the
/// live blog. Production never constructs this (gated on the launch flag).
///
/// The fixtures live in ``E2EFixtures`` and cover the endpoints the app hits:
/// the `/wp/v2/posts` list + single-post, `/comments`, `/categories`, `/media`,
/// the recipe detail HTML page (with embedded JSON-LD), images, and the WPRM
/// ratings endpoint (which the real site 403s — mirrored so ratings degrade
/// gracefully). Anything unmatched returns an empty `200` so nothing hangs.
struct E2EStubHTTPClient: HTTPClient {

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { return Self.empty(for: request.url) }
        let path = url.path
        let query = Self.queryItems(url)

        // WPRM ratings — the live endpoint returns 401/403; mirror it so the
        // rating summary degrades to "no aggregate" without breaking the screen.
        if path.contains("wp-recipe-maker") || path.contains("wprm") {
            return Self.response(E2EFixtures.ratingsForbiddenJSON, url: url, status: 403)
        }

        // Recipe detail HTML page: a dutchovendaddy.com URL that is NOT a wp-json
        // API call (RecipePageFetcher fetches the post's canonical `link`).
        if !path.contains("/wp-json/"), let recipe = E2EFixtures.recipe(forSlug: url.slug) {
            return Self.response(E2EFixtures.detailHTML(for: recipe), contentType: "text/html", url: url)
        }

        // Images (gravatar avatars, media source URLs) → a 1×1 PNG.
        if Self.isImageRequest(url) {
            return Self.response(E2EFixtures.onePixelPNG, contentType: "image/png", url: url)
        }

        // WP REST API.
        if path.contains("/wp/v2/posts/"), let id = Self.trailingID(path) {
            let post = E2EFixtures.recipe(forID: id).map { E2EFixtures.postJSONObject($0) }
            return Self.json(post ?? [:], url: url)
        }
        if path.hasSuffix("/wp/v2/posts") || path.contains("/wp/v2/posts") {
            return Self.json(E2EFixtures.postsListJSONObjects(matching: query), url: url)
        }
        if path.contains("/wp/v2/comments") {
            return Self.json(E2EFixtures.commentsJSONObjects, url: url)
        }
        if path.contains("/wp/v2/categories") {
            return Self.json(E2EFixtures.categoriesJSONObjects, url: url)
        }
        if path.contains("/wp/v2/media/") {
            return Self.json(E2EFixtures.mediaJSONObject, url: url)
        }

        // Unknown endpoint — empty 200 (an empty JSON array is a valid decode
        // for every list caller and keeps the app from hanging on a stub miss).
        return Self.json([[String: Any]](), url: url)
    }

    // MARK: - Helpers

    private static func trailingID(_ path: String) -> Int? {
        Int(path.split(separator: "/").last ?? "")
    }

    private static func isImageRequest(_ url: URL) -> Bool {
        let host = url.host ?? ""
        if host.contains("gravatar.com") { return true }
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "webp", "gif"].contains(ext)
    }

    private static func queryItems(_ url: URL) -> [String: String] {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var out: [String: String] = [:]
        for item in components?.queryItems ?? [] where item.value != nil {
            out[item.name] = item.value
        }
        return out
    }

    private static func json(_ object: Any, url: URL, status: Int = 200) -> (Data, HTTPURLResponse) {
        let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("[]".utf8)
        return response(data, contentType: "application/json", url: url, status: status)
    }

    private static func response(
        _ data: Data,
        contentType: String = "application/json",
        url: URL,
        status: Int = 200
    ) -> (Data, HTTPURLResponse) {
        // HTTPURLResponse's failable init never returns nil for a valid URL +
        // status code, so the force unwrap is safe here (test-support only).
        // swiftlint:disable force_unwrapping
        let http = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType, "X-WP-TotalPages": "1"]
        )!
        // swiftlint:enable force_unwrapping
        return (data, http)
    }

    private static func empty(for url: URL?) -> (Data, HTTPURLResponse) {
        let resolved = url ?? URL(string: "https://www.dutchovendaddy.com/") ?? URL(filePath: "/")
        return response(Data("[]".utf8), url: resolved)
    }
}

extension URL {
    /// The last non-empty path component — the recipe slug for a canonical page
    /// URL like `https://www.dutchovendaddy.com/garlic-butter-skillet-corn/`.
    fileprivate var slug: String {
        pathComponents.last(where: { $0 != "/" && !$0.isEmpty }) ?? ""
    }
}
