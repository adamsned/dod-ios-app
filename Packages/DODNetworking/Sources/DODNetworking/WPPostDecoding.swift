import Foundation

extension WPDTO.Post {

    /// DUT-360: decode `link` leniently so one malformed/empty link can't fail the
    /// whole posts-page decode (the `[Post]` array is otherwise all-or-nothing) —
    /// fall back to the site root so the rest of the page still renders. Lives in
    /// an extension so this stays decoupled from the DTO declaration in `WPDTOs`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        slug = try container.decode(String.self, forKey: .slug)
        let linkString = try? container.decode(String.self, forKey: .link)
        link =
            WPDTO.parseOptionalURL(linkString)
            ?? URL(string: "https://www.dutchovendaddy.com/") ?? URL(filePath: "/")
        title = try container.decode(WPDTO.RenderedString.self, forKey: .title)
        excerpt = try container.decode(WPDTO.RenderedString.self, forKey: .excerpt)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        dateGMT = try container.decodeIfPresent(String.self, forKey: .dateGMT)
        featuredMedia = try container.decodeIfPresent(Int.self, forKey: .featuredMedia)
        categories = try container.decodeIfPresent([Int].self, forKey: .categories)
        embedded = try container.decodeIfPresent(WPDTO.PostEmbedded.self, forKey: .embedded)
    }
}
