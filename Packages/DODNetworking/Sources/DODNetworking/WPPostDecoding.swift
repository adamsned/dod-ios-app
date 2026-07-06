import Foundation

extension WPDTO.Post {

    /// DUT-360: decode `link` leniently so one malformed/empty link can't fail the
    /// whole posts-page decode (the `[Post]` array is otherwise all-or-nothing) —
    /// fall back to the site root so the rest of the page still renders. Lives in
    /// an extension so this stays decoupled from the DTO declaration in `WPDTOs`.
    ///
    /// DUT-575: `title`/`excerpt` are decoded leniently too, mirroring the
    /// `WPDTO.Comment` DTO's `content` handling (DUT-27/384): a draft-state /
    /// ACF-edge post with `title: null` (or an absent/mis-shaped `title`/
    /// `excerpt`) now falls back to an empty rendered string instead of throwing
    /// and — combined with the lossy array decode in `getPaged`/`get` — nuking
    /// the whole page. `id` stays required: a post with no id is unusable.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        slug = (try? container.decode(String.self, forKey: .slug)) ?? ""
        let linkString = try? container.decode(String.self, forKey: .link)
        link =
            WPDTO.parseOptionalURL(linkString)
            ?? URL(string: "https://www.dutchovendaddy.com/") ?? URL(filePath: "/")
        title = (try? container.decode(WPDTO.RenderedString.self, forKey: .title)) ?? WPDTO.RenderedString(rendered: "")
        excerpt =
            (try? container.decode(WPDTO.RenderedString.self, forKey: .excerpt)) ?? WPDTO.RenderedString(rendered: "")
        date = try container.decodeIfPresent(String.self, forKey: .date)
        dateGMT = try container.decodeIfPresent(String.self, forKey: .dateGMT)
        featuredMedia = try container.decodeIfPresent(Int.self, forKey: .featuredMedia)
        categories = try container.decodeIfPresent([Int].self, forKey: .categories)
        // DUT-640: decode `_embedded` leniently. A malformed embedded block
        // (e.g. `wp:featuredmedia` carrying a WP error object instead of a media
        // array) should cost only the inline hero image, not the whole post —
        // the hero re-hydrates later via the `/media/{id}` fallback.
        embedded = try? container.decodeIfPresent(WPDTO.PostEmbedded.self, forKey: .embedded)
    }
}
