import DODDomain
import Foundation

/// Reads the public WPRM rating summary and posts new ratings.
///
/// Spec trace: spec.md US-14 (read and submit a star rating) + REG-14
/// (average stays in 0.0...5.0 and count stays ≥ 0 even when the upstream
/// endpoint is unreachable — the client degrades to a zero-valued summary
/// rather than throwing).
public struct WPRMRatingsClient: Sendable {

    /// WPRM lives at a different namespace than core WP REST, so it gets its
    /// own base URL.
    public static let defaultBaseURL =
        URL(string: "https://www.dutchovendaddy.com/wp-json/wp-recipe-maker/v1/")
        ?? URL(filePath: "/")

    let baseURL: URL
    let httpClient: HTTPClient
    let decoder: JSONDecoder

    public init(
        baseURL: URL = WPRMRatingsClient.defaultBaseURL,
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) {
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.decoder = JSONDecoder()
    }

    // MARK: - Public surface

    /// Fetch the public aggregate rating for a recipe.
    ///
    /// Some WPRM deployments require auth even on the public GET — when the
    /// endpoint returns 401/403 the client honors REG-14 by returning a
    /// zero-valued summary instead of throwing. Any other non-success status
    /// surfaces as ``WPClientError/httpStatus(_:)``.
    public func summary(forRecipeID recipeID: Int) async throws -> RecipeRating {
        let url = try buildURL(path: "rating/recipe/\(recipeID)", queryItems: [])
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"
        // DUT-355: bypass URLSession heuristic freshness + Cloudflare edge cache so a
        // post-write refresh reads the just-submitted vote, not a stale aggregate
        // (WP REST sends only Last-Modified — see WPRestClient.getPaged).
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        let (data, response): (Data, HTTPURLResponse)
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch WPClientError.networkUnavailable {
            // REG-14: degrade gracefully when the device is offline.
            return Self.zeroRating(for: recipeID)
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            return Self.zeroRating(for: recipeID)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw WPClientError.httpStatus(response.statusCode)
        }
        do {
            let dto = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: data)
            return RecipeRating(
                recipeID: recipeID,
                average: dto.average,
                count: dto.count,
                userRating: nil
            )
        } catch {
            // REG-14: any decode hiccup degrades to a safe zero-rating
            // rather than blocking the recipe detail screen.
            return Self.zeroRating(for: recipeID)
        }
    }

    /// Submit a star rating. WPRM dedupes by email, so a repeat call from
    /// the same identity overwrites the previous vote rather than adding a
    /// new one.
    ///
    /// Returns the freshly-fetched summary so callers can render the new
    /// average without a separate round-trip.
    public func postRating(
        recipeID: Int,
        stars: Int,
        authorName: String,
        authorEmail: String
    ) async throws -> RecipeRating {
        guard (1...5).contains(stars) else {
            throw WPClientError.underlying(message: "stars must be 1...5; got \(stars)")
        }
        let url = try buildURL(path: "rating", queryItems: [])
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.httpBody = try Self.encodePostBody(
            recipeID: recipeID,
            stars: stars,
            authorName: authorName,
            authorEmail: authorEmail
        )

        let (_, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            // Bubble auth errors verbatim — the host UI can decide whether
            // to prompt for sign-in. We never expect this path on a
            // guest-comments-enabled blog like DOD.
            throw WPClientError.httpStatus(response.statusCode)
        }
        // DUT-305: the rating WAS recorded the moment the POST returned 2xx.
        // The follow-up summary GET is a best-effort convenience to render the
        // updated average without a second round-trip — if it fails (or 5xx),
        // we must NOT report the whole submit as failed and must NOT hand back
        // a zeroed aggregate. Fall back to a RecipeRating built from the star
        // we just submitted so the caller can reconcile (DUT-216) rather than
        // blanking the user's vote.
        do {
            let updated = try await summary(forRecipeID: recipeID)
            return RecipeRating(
                recipeID: updated.recipeID,
                average: updated.average,
                count: updated.count,
                userRating: stars
            )
        } catch {
            return RecipeRating(
                recipeID: recipeID,
                average: Double(stars),
                count: 1,
                userRating: stars
            )
        }
    }

    // MARK: - Internals

    func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        let resolved = baseURL.appending(path: path)
        guard var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) else {
            throw WPClientError.underlying(message: "Bad base URL")
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw WPClientError.underlying(message: "Bad URL components")
        }
        return url
    }

    static func encodePostBody(
        recipeID: Int,
        stars: Int,
        authorName: String,
        authorEmail: String
    ) throws -> Data {
        let payload: [String: Any] = [
            "recipe_id": recipeID,
            "rating": stars,
            "name": authorName,
            "email": authorEmail,
        ]
        do {
            return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        } catch {
            throw WPClientError.underlying(message: "Failed to encode rating body: \(error)")
        }
    }

    static func zeroRating(for recipeID: Int) -> RecipeRating {
        RecipeRating(recipeID: recipeID, average: 0, count: 0, userRating: nil)
    }
}
