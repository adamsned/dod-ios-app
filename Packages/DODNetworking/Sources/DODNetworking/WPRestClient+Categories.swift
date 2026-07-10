import DODDomain
import Foundation

extension WPRestClient {

    /// Fetch all categories, alphabetically sorted, empties hidden.
    /// Spec trace: AC-2.1, AC-2.2, AC-2.4.
    public func categories() async throws -> [DODDomain.Category] {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "hide_empty", value: "true"),
            URLQueryItem(name: "_fields", value: "id,name,slug,count"),
        ]
        // A single malformed row (e.g. a taxonomy entry missing a required
        // field) otherwise fails the ENTIRE `[WPDTO.Category]` decode,
        // dropping every valid category. `LossyArray` skips just the bad row,
        // mirroring the `posts()` / `search()` / comments fix (DUT-575) —
        // that fix covered posts and comments but missed this endpoint.
        let lossy: LossyArray<WPDTO.Category> = try await get(path: "categories", queryItems: queryItems)
        return
            lossy.elements
            .filter { $0.count >= 1 }
            .map { $0.toDomain() }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
