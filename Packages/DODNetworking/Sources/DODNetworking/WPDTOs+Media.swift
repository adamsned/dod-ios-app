import Foundation

extension WPDTO.MediaDetails {

    // Declared here (not on the struct) so the custom `init(from:)` in this
    // extension resolves `.sizes` while keeping `WPDTOs.swift` under the
    // file_length limit.
    enum CodingKeys: String, CodingKey {
        case sizes
    }

    /// DUT-640: WordPress serializes `media_details.sizes` as an empty JSON
    /// array (`[]`, PHP's `json_encode([])` quirk) when a media item has no
    /// generated sizes — which is NOT a keyed container. The synthesized
    /// decoder throws on that shape, and in the feed's `LossyArray` that
    /// silently DROPS the whole post (and fails non-lossy deep-link fetches).
    /// Treat a non-keyed / `[]` container as "no sizes" (`sizes = nil`) rather
    /// than throwing — mirroring ``WPDTO.CommentMeta/init(from:)`` (DUT-27),
    /// which guards the exact same WP empty-array quirk for comment meta.
    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.sizes = nil
            return
        }
        self.sizes = try? container.decodeIfPresent([String: WPDTO.MediaSize].self, forKey: .sizes)
    }
}
