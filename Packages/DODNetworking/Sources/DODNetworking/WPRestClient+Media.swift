import Foundation

extension WPRestClient {

    /// Resolved image URLs for a recipe's featured media. Two size buckets:
    /// `list` (~768px wide) for feed rows, `hero` (largest ≤ 2048px) for
    /// recipe detail. Spec trace: CL-6, AC-4.1.
    public struct MediaSizes: Sendable, Hashable {
        public let listImageURL: URL?
        public let heroImageURL: URL?
    }

    /// Fetch sized image URLs for a media item.
    public func media(id: Int) async throws -> MediaSizes {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "_fields", value: "source_url,media_details")
        ]
        let media: WPDTO.Media = try await get(path: "media/\(id)", queryItems: queryItems)
        return Self.resolveSizes(from: media)
    }

    static func resolveSizes(from media: WPDTO.Media) -> MediaSizes {
        let sizes = media.mediaDetails?.sizes ?? [:]

        // List: prefer medium_large, fallback to medium, fallback to source.
        let list =
            sizes["medium_large"]?.sourceURL
            ?? sizes["medium"]?.sourceURL
            ?? media.sourceURL

        // Hero: pick the largest derivative ≤ 2048px, fallback to source.
        let candidates = sizes.values.filter { ($0.width ?? 0) <= 2048 }
        let largest = candidates.max(by: { ($0.width ?? 0) < ($1.width ?? 0) })
        let hero = largest?.sourceURL ?? media.sourceURL

        return MediaSizes(listImageURL: list, heroImageURL: hero)
    }
}
