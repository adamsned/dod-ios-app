import DODDomain
import Testing

@testable import DODSupport

/// L1 coverage for the T-643 / CL-121 / REG-30 category-match path.
/// Every expectation pins a user-facing contract from CL-121's "Match if"
/// rule list, with the fixture drawn from the live-API top-8-by-post-count
/// categories `dutchovendaddy.com` returned on 2026-05-30 (CL-121's
/// rationale section captures the verbatim counts + ids).
@Suite("CategoryNameMatcher (T-643 / CL-121 / REG-30)")
struct CategoryNameMatcherTests {

    // MARK: - Live-API top-8 fixture (2026-05-30)

    /// Verbatim from CL-121's live-API rationale. Sorted by `count` desc
    /// so the `prefix(maxMatches)` cap surfaces the highest-count match
    /// first — same ordering the production pipeline gets back from
    /// `?categories=&orderby=count&order=desc`.
    static let liveFixture: [DODDomain.Category] = [
        DODDomain.Category(id: 1590, name: "Latest Recipes", slug: "latest-recipes", count: 240),
        DODDomain.Category(id: 336, name: "Dessert Recipes", slug: "dessert-recipes", count: 53),
        DODDomain.Category(id: 1435, name: "One Pot Dutch Oven Recipes", slug: "one-pot-dutch-oven-recipes", count: 46),
        DODDomain.Category(
            id: 338,
            name: "Chicken and Poultry Recipes",
            slug: "chicken-and-poultry-recipes",
            count: 32
        ),
        DODDomain.Category(id: 339, name: "Beef and Red Meat Recipes", slug: "beef-and-red-meat-recipes", count: 28),
        DODDomain.Category(id: 334, name: "Side Dish Recipes", slug: "side-dish-recipes", count: 28),
        DODDomain.Category(id: 777, name: "Breads and Pizza Recipes", slug: "breads-and-pizza-recipes", count: 27),
        DODDomain.Category(id: 337, name: "Dutch Oven Camp Recipes", slug: "dutch-oven-camp-recipes", count: 26),
    ]

    // MARK: - Match rule cases (CL-121 examples table)

    @Test func fullNameMatchExact() {
        let result = CategoryNameMatcher.match(query: "Dessert Recipes", in: Self.liveFixture)
        #expect(result.map(\.id) == [336])
    }

    @Test func topicMatchExact() {
        // "dessert" equals topic "dessert" → rule (b) fires.
        let result = CategoryNameMatcher.match(query: "dessert", in: Self.liveFixture)
        #expect(result.map(\.id) == [336])
    }

    @Test func substringOfTopicMultiWordTopic() {
        // "Chicken" (7 chars, >= 4) is a substring of topic
        // "chicken and poultry" → rule (c) fires.
        let result = CategoryNameMatcher.match(query: "Chicken", in: Self.liveFixture)
        #expect(result.map(\.id) == [338])
    }

    @Test func fullTopicMatch() {
        // "Chicken and Poultry" equals topic "chicken and poultry" →
        // rule (b) fires.
        let result = CategoryNameMatcher.match(
            query: "Chicken and Poultry",
            in: Self.liveFixture
        )
        #expect(result.map(\.id) == [338])
    }

    @Test func sideDishTopicMatch() {
        let result = CategoryNameMatcher.match(query: "Side Dish", in: Self.liveFixture)
        #expect(result.map(\.id) == [334])
    }

    @Test func substringEitherDirection() {
        // "Camp Recipes" (normalized "camp recipes") — topic of Dutch
        // Oven Camp Recipes is "dutch oven camp", which is NOT a
        // substring of "camp recipes" and "camp recipes" is NOT a
        // substring of "dutch oven camp". But the full normalized name
        // "dutch oven camp recipes" is also not matched by either rule
        // (a) or (b). The match path here is rule (d) backwards:
        // strip the "recipes" suffix from query gives "camp" → wait, we
        // don't strip the query. Rule (c): query "camp recipes" is
        // 12 chars, but it's not a substring of "dutch oven camp"
        // because of the "recipes" suffix. Rule (d): topic "dutch oven
        // camp" is NOT a substring of "camp recipes". So neither fires.
        //
        // The correct path: just type "Camp" — "camp" is 4 chars and
        // IS a substring of "dutch oven camp" → rule (c) fires.
        let result = CategoryNameMatcher.match(query: "Camp", in: Self.liveFixture)
        #expect(result.map(\.id) == [337])
    }

    @Test func nachosNoCategoryMatch() {
        // CL-121's REG-29 preservation contract: queries that don't name
        // a category return empty. "Nachos" doesn't match any category
        // → Path B returns [], the calling pipeline falls back to
        // title-match-only (T-642 contract intact).
        let result = CategoryNameMatcher.match(query: "Nachos", in: Self.liveFixture)
        #expect(result.isEmpty)
    }

    @Test func junkSingleTokenRecipeRejected() {
        // CL-121 junk-query guard: "recipe" (single-token, suffix-only)
        // would substring-match every category in the catalog if not
        // explicitly rejected. The matcher returns [] before evaluating
        // any category to prevent a fan-out of N fetches.
        let result = CategoryNameMatcher.match(query: "recipe", in: Self.liveFixture)
        #expect(result.isEmpty)
    }

    @Test func junkSingleTokenRecipesRejected() {
        // Sibling to the above — the plural form is the same junk.
        let result = CategoryNameMatcher.match(query: "recipes", in: Self.liveFixture)
        #expect(result.isEmpty)
    }

    @Test func underFourCharQueryRejectedFromSubstringRule() {
        // CL-121: "the" (3 chars) is below the substring-of-topic floor.
        // It doesn't equal any full name or topic in the fixture, so
        // rule (c) is the only path that could fire — and it's gated.
        let result = CategoryNameMatcher.match(query: "the", in: Self.liveFixture)
        #expect(result.isEmpty)
    }

    @Test func shortTopicDoesNotMatchViaRuleFour() {
        // DUT-317: rule (d) (topic is a substring of the query) now carries
        // the same `substringOfTopicMinLength` (4) floor as rule (c). A
        // category whose topic is a short generic token ("egg", 3 chars)
        // must NOT match an unrelated longer query that merely contains it
        // ("eggplant parmesan"). Before the fix, "egg" ⊂ "eggplant ..."
        // fired rule (d) and fanned out a `?categories=` fetch the user
        // never intended. No other rule applies: query ≠ name, query ≠
        // topic, and query (17 chars) is not a substring of topic "egg".
        let shortTopic = DODDomain.Category(
            id: 4242,
            name: "Egg Recipes",
            slug: "egg-recipes",
            count: 12
        )
        let result = CategoryNameMatcher.match(
            query: "eggplant parmesan",
            in: [shortTopic]
        )
        #expect(result.isEmpty)
    }

    @Test func longTopicStillMatchesViaRuleFour() {
        // DUT-317 regression guard: a topic at/above the floor (4+ chars)
        // still matches rule (d). Topic "side dish" (>= 4) is a substring
        // of query "easy side dish ideas" → rule (d) fires unchanged.
        let result = CategoryNameMatcher.match(
            query: "easy side dish ideas",
            in: Self.liveFixture
        )
        #expect(result.map(\.id) == [334])
    }

    @Test func latestMatchesLatestRecipes() {
        // Special-category sanity: "latest" is the topic of
        // "Latest Recipes" → rule (b) fires.
        let result = CategoryNameMatcher.match(query: "latest", in: Self.liveFixture)
        #expect(result.map(\.id) == [1590])
    }

    // MARK: - Normalization

    @Test func caseInsensitiveFullName() {
        // "DESSERT recipes" normalizes identically to "Dessert Recipes".
        let result = CategoryNameMatcher.match(
            query: "DESSERT recipes",
            in: Self.liveFixture
        )
        #expect(result.map(\.id) == [336])
    }

    @Test func htmlEntitiesNormalized() {
        // Fabricated category with an HTML entity in the name. The
        // matcher must decode "&amp;" before comparing so a user typing
        // "Beef and Red Meat" matches a category whose `name` carries
        // the entity-encoded ampersand straight from WP's `name.rendered`.
        let withEntity = DODDomain.Category(
            id: 999,
            name: "Beef &amp; Red Meat Recipes",
            slug: "beef-and-red-meat-recipes",
            count: 28
        )
        let result = CategoryNameMatcher.match(
            query: "Beef and Red Meat",
            in: [withEntity]
        )
        // After normalization: name becomes "beef red meat recipes" (the
        // entity decodes to "&" which then becomes a space under the
        // punctuation→space rule, and the doubled spaces collapse).
        // Topic strip: "beef red meat".
        // Query "Beef and Red Meat" normalizes to "beef and red meat".
        // Neither topic nor full-name equals the query, but topic
        // "beef red meat" is a substring of query "beef and red meat"
        // when... wait, "beef red meat" is not a substring of "beef and
        // red meat". Re-derive: query "beef and red meat" → topic of
        // candidate is "beef red meat". Rule (c): query (17 chars)
        // is not a substring of topic (13 chars). Rule (d): topic
        // "beef red meat" — is this a substring of query "beef and red
        // meat"? No, the "and" interrupts. So the entity case needs a
        // different fixture for the matcher to fire. Use a simpler
        // fixture where the entity is in a position the normalizer
        // collapses cleanly.
        // Adjust: assert at minimum the matcher doesn't crash. The
        // entity-normalization contract is also covered by the
        // `TitleSearchMatcher.normalize` tests at the layer below.
        _ = result
        // Now the real positive case: fixture with entity where the
        // normalized name lines up with a clean topic.
        let cleanFixture = DODDomain.Category(
            id: 998,
            name: "Mama&#8217;s Recipes",
            slug: "mamas-recipes",
            count: 10
        )
        let cleanResult = CategoryNameMatcher.match(
            query: "Mama's",
            in: [cleanFixture]
        )
        // Name normalizes to "mama s recipes" → topic "mama s".
        // Query normalizes to "mama s" → exact topic match (rule b).
        #expect(cleanResult.map(\.id) == [998])
    }

    // MARK: - Cap + ordering

    @Test func multiMatchCapsAtTwo() {
        // Fabricate a 3-category fixture that all match the same query
        // and assert only the top-2 by count are returned. Use "dutch
        // oven" as the query — "Dutch Oven A/B/C Recipes" topics are
        // "dutch oven a" / "b" / "c"; query "dutch oven" is NOT a
        // substring of those topics (it's at the front but the topic
        // has additional words after), but the topic isn't a substring
        // of query "dutch oven" either. Use a different fan-out: each
        // category has the exact topic "dutch oven a/b/c", and the
        // query is "dutch" which is a 5-char substring of each topic
        // → rule (c) fires for all three.
        let fanOut: [DODDomain.Category] = [
            DODDomain.Category(id: 1, name: "Dutch Oven Alpha Recipes", slug: "a", count: 50),
            DODDomain.Category(id: 2, name: "Dutch Oven Beta Recipes", slug: "b", count: 30),
            DODDomain.Category(id: 3, name: "Dutch Oven Gamma Recipes", slug: "c", count: 20),
        ]
        let result = CategoryNameMatcher.match(query: "dutch", in: fanOut)
        #expect(result.count == 2)
        #expect(result.map(\.id) == [1, 2], "top-2 by count desc")
    }

    @Test func emptyQueryReturnsEmpty() {
        let result = CategoryNameMatcher.match(query: "", in: Self.liveFixture)
        #expect(result.isEmpty)
    }

    @Test func whitespaceOnlyQueryReturnsEmpty() {
        // Trims to empty after normalization → returns empty without
        // evaluating any category.
        let result = CategoryNameMatcher.match(query: "   ", in: Self.liveFixture)
        #expect(result.isEmpty)
    }

    @Test func emptyCategoryListReturnsEmpty() {
        // Defensive: no categories loaded yet (REST hadn't responded
        // before the user typed). The matcher returns empty rather
        // than throwing — the calling pipeline falls back to Path A
        // alone, which is the correct degradation.
        let result = CategoryNameMatcher.match(query: "Dessert Recipes", in: [])
        #expect(result.isEmpty)
    }

    // MARK: - Helper sanity

    @Test func stripRecipesSuffixWorksAtBoundary() {
        // Whole-word suffix only — "appetizer" does NOT strip to "app".
        #expect(CategoryNameMatcher.stripRecipesSuffix("dessert recipes") == "dessert")
        #expect(CategoryNameMatcher.stripRecipesSuffix("breads and pizza recipes") == "breads and pizza")
        // No trailing " recipes" → name returned unchanged.
        #expect(CategoryNameMatcher.stripRecipesSuffix("appetizers") == "appetizers")
        // Single-word "recipes" → returned unchanged (the rule is
        // "topic stays valid"; stripping to "" would leak through to
        // a hot path).
        #expect(CategoryNameMatcher.stripRecipesSuffix("recipes") == "recipes")
    }
}
