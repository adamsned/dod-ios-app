import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// DUT-640: WordPress serializes `media_details.sizes` as an empty JSON array
/// (`[]`) when a media item has no generated sizes. The synthesized decoder
/// threw on that non-keyed shape, and in the feed's `LossyArray` that silently
/// DROPPED the whole post (and failed non-lossy deep-link fetches). The custom
/// `MediaDetails.init(from:)` now treats `[]` / non-keyed as "no sizes".
@Suite("WP media_details.sizes=[] tolerance (DUT-640)") struct WPMediaSizesEmptyArrayTests {

    private func decodePost(_ json: String) throws -> WPDTO.Post {
        try JSONDecoder().decode(WPDTO.Post.self, from: Data(json.utf8))
    }

    /// A post whose embedded featured media reports `media_details.sizes: []`
    /// (the `json_encode([])` quirk) must decode WITHOUT throwing, land
    /// `sizes == nil`, and still surface a hero from the media `source_url`.
    private let postWithEmptySizesArray = #"""
        {
          "id": 77,
          "slug": "no-sizes",
          "link": "https://www.dutchovendaddy.com/no-sizes/",
          "title": { "rendered": "No Sizes" },
          "excerpt": { "rendered": "<p>Body.</p>" },
          "featured_media": 900,
          "_embedded": {
            "wp:featuredmedia": [
              {
                "source_url": "https://example.com/original.jpg",
                "media_details": { "sizes": [] }
              }
            ]
          }
        }
        """#

    @Test func emptySizesArrayDecodesToNilSizesWithoutThrowing() throws {
        let post = try decodePost(postWithEmptySizesArray)
        let media = try #require(post.embedded?.featuredMedia?.first)
        // The whole point: `sizes: []` becomes nil rather than throwing.
        #expect(media.mediaDetails?.sizes == nil)
        // Hero still resolves from the bare `source_url` fallback.
        #expect(post.inlineHeroURL?.absoluteString == "https://example.com/original.jpg")
    }

    /// The lossy feed decode must KEEP a post carrying `sizes: []` rather than
    /// dropping it — the exact silent-data-loss the synthesized decoder caused.
    @Test func lossyFeedKeepsPostWithEmptySizesArray() async throws {
        let page = "[\(postWithEmptySizesArray)]"
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(page.utf8))
        let client = WPRestClient(httpClient: fake)

        let items = try await client.posts()

        #expect(items.map { $0.id } == [77])
        #expect(items.first?.heroImage?.absoluteString == "https://example.com/original.jpg")
    }

    /// A media item that reports `media_details: []` (the empty-array quirk one
    /// level up) is likewise tolerated: no sizes, no throw.
    @Test func emptyMediaDetailsArrayIsTolerated() throws {
        let json = #"""
            {
              "id": 78,
              "slug": "empty-details",
              "link": "https://www.dutchovendaddy.com/empty-details/",
              "title": { "rendered": "Empty Details" },
              "excerpt": { "rendered": "<p>Body.</p>" },
              "_embedded": {
                "wp:featuredmedia": [
                  {
                    "source_url": "https://example.com/plain.jpg",
                    "media_details": []
                  }
                ]
              }
            }
            """#
        let post = try decodePost(json)
        let media = try #require(post.embedded?.featuredMedia?.first)
        #expect(media.mediaDetails?.sizes == nil)
        #expect(post.inlineHeroURL?.absoluteString == "https://example.com/plain.jpg")
    }
}

/// DUT-640: a malformed `_embedded` block must cost only the inline hero, not
/// the whole post — the post decodes, hero is nil, and the `/media/{id}`
/// fallback re-hydrates it later.
@Suite("WP malformed _embedded is lenient (DUT-640)") struct WPMalformedEmbeddedTests {

    private func decodePost(_ json: String) throws -> WPDTO.Post {
        try JSONDecoder().decode(WPDTO.Post.self, from: Data(json.utf8))
    }

    /// `_embedded` arrives as a mis-shaped value (here the WP empty-array
    /// quirk, `[]` — a non-keyed container) instead of the expected object —
    /// the shape that previously threw and (in `LossyArray`) nuked the post.
    /// The `try?` now swallows it: no embedded, no inline hero, post survives.
    private let postWithBrokenEmbedded = #"""
        {
          "id": 80,
          "slug": "broken-embed",
          "link": "https://www.dutchovendaddy.com/broken-embed/",
          "title": { "rendered": "Broken Embed" },
          "excerpt": { "rendered": "<p>Body.</p>" },
          "featured_media": 42,
          "_embedded": []
        }
        """#

    @Test func malformedEmbeddedYieldsPostWithNoHeroNoThrow() throws {
        let post = try decodePost(postWithBrokenEmbedded)
        #expect(post.id == 80)
        // `_embedded` decode failed leniently → no embedded, no inline hero.
        #expect(post.embedded == nil)
        #expect(post.inlineHeroURL == nil)
    }

    @Test func lossyFeedKeepsPostWithMalformedEmbedded() async throws {
        let page = "[\(postWithBrokenEmbedded)]"
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(page.utf8))
        let client = WPRestClient(httpClient: fake)

        let items = try await client.posts()

        #expect(items.map { $0.id } == [80])
        #expect(items.first?.heroImage == nil)
    }
}

/// DUT-645: WP appends a trailing `<a class="more-link">…</a>` (inner text
/// "Continue reading …" / `[…]`) to `excerpt.rendered`; it survives
/// tag-stripping and leaks into list-row excerpts. It must be stripped when
/// sanitizing the excerpt.
@Suite("WP excerpt more-link stripped (DUT-645)") struct WPExcerptMoreLinkTests {

    private func decodePost(_ json: String) throws -> WPDTO.Post {
        try JSONDecoder().decode(WPDTO.Post.self, from: Data(json.utf8))
    }

    @Test func moreLinkTrailerIsStrippedFromExcerpt() throws {
        let json = #"""
            {
              "id": 90,
              "slug": "more-link",
              "link": "https://www.dutchovendaddy.com/more-link/",
              "title": { "rendered": "More Link" },
              "excerpt": {
                "rendered": "<p>A crispy, golden cornbread. <a class=\"more-link\" href=\"https://www.dutchovendaddy.com/more-link/\">Continue reading</a></p>"
              }
            }
            """#
        let item = try decodePost(json).toRecipeListItem(heroImage: nil)
        #expect(item.excerpt == "A crispy, golden cornbread.")
        #expect(!item.excerpt.contains("Continue reading"))
    }

    @Test func bracketedContinueReadingVariantIsStripped() throws {
        // WP's classic `[…] Continue reading` more-link inner text.
        let json = #"""
            {
              "id": 91,
              "slug": "more-link-brackets",
              "link": "https://www.dutchovendaddy.com/more-link-brackets/",
              "title": { "rendered": "More Link Brackets" },
              "excerpt": {
                "rendered": "<p>Low and slow brisket. <a class=\"more-link\" href=\"#\">[&hellip;] Continue reading</a></p>"
              }
            }
            """#
        let item = try decodePost(json).toRecipeListItem(heroImage: nil)
        #expect(item.excerpt == "Low and slow brisket.")
    }

    @Test func excerptWithoutMoreLinkIsUntouched() throws {
        let json = #"""
            {
              "id": 92,
              "slug": "no-more-link",
              "link": "https://www.dutchovendaddy.com/no-more-link/",
              "title": { "rendered": "No More Link" },
              "excerpt": { "rendered": "<p>Just a plain excerpt.</p>" }
            }
            """#
        let item = try decodePost(json).toRecipeListItem(heroImage: nil)
        #expect(item.excerpt == "Just a plain excerpt.")
    }
}
