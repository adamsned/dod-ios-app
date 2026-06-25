import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// DUT-311: `date` is site-local without an offset, so labeling it as UTC
/// (parseWPDate appends "Z") can shift the displayed calendar day. `date_gmt`
/// is genuine UTC, so it must drive `RecipeListItem.publishedAt`.
@Suite("WP Post publishedAt uses date_gmt (DUT-311)") struct WPPostPublishedDateTests {

    private func decodePost(_ json: String) throws -> WPDTO.Post {
        try JSONDecoder().decode(WPDTO.Post.self, from: Data(json.utf8))
    }

    @Test func publishedAtComesFromDateGMTNotLocalDate() throws {
        // Site-local `date` is the evening of May 23; `date_gmt` is the early
        // morning of May 24 UTC. If `date` drove publishedAt, parseWPDate would
        // mislabel "2026-05-23T22:00:00" as UTC and land on the wrong day.
        let json = #"""
            {
              "id": 42,
              "slug": "smoky-brisket",
              "link": "https://dutchovendaddy.com/smoky-brisket",
              "title": { "rendered": "Smoky Brisket" },
              "excerpt": { "rendered": "Low and slow." },
              "date": "2026-05-23T22:00:00",
              "date_gmt": "2026-05-24T04:00:00",
              "featured_media": 0,
              "categories": [7]
            }
            """#
        let post = try decodePost(json)
        let item = post.toRecipeListItem(heroImage: nil)

        let expected = WPDTO.parseWPDate("2026-05-24T04:00:00")
        #expect(item.publishedAt == expected)
        // And explicitly NOT the local-date interpretation.
        #expect(item.publishedAt != WPDTO.parseWPDate("2026-05-23T22:00:00"))
    }

    @Test func fallsBackToDateWhenGMTAbsent() throws {
        // Older payloads / edge cases may omit `date_gmt`; we still produce a
        // timestamp from `date` rather than defaulting to now.
        let json = #"""
            {
              "id": 43,
              "slug": "campfire-cornbread",
              "link": "https://dutchovendaddy.com/campfire-cornbread",
              "title": { "rendered": "Campfire Cornbread" },
              "excerpt": { "rendered": "Golden crust." },
              "date": "2026-05-23T08:00:00",
              "featured_media": 0
            }
            """#
        let post = try decodePost(json)
        let item = post.toRecipeListItem(heroImage: nil)

        #expect(item.publishedAt == WPDTO.parseWPDate("2026-05-23T08:00:00"))
    }
}
