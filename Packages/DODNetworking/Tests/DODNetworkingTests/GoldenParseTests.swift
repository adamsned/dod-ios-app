import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// Golden-file contract tests. Each fixture is a real HTML page captured
/// from dutchovendaddy.com on 2026-05-23. These lock the JSON-LD shape so
/// any future WPRM upgrade that changes it is caught loudly (risk R-1 in
/// plan.md §8).
///
/// To refresh fixtures, see the curl loop in tasks.md T-061 history.
@Suite("Golden-file JSON-LD parse contract (T-062)") struct GoldenParseTests {

    /// Four recipe fixtures must all parse to a populated Recipe.
    @Test(arguments: ["cake", "savory", "soup", "bread"])
    func recipePagesParseSuccessfully(_ fixtureName: String) throws {
        let html = try loadFixture(fixtureName)
        let recipe = try JSONLDRecipeParser.parse(
            html: html,
            merging: Self.placeholderListItem,
            canonicalURL: Self.placeholderURL
        )
        #expect(!recipe.ingredients.isEmpty, "\(fixtureName) had no ingredients")
        #expect(!recipe.instructions.isEmpty, "\(fixtureName) had no instructions")
        #expect(recipe.totalTime != nil, "\(fixtureName) had no totalTime")
    }

    /// The temperature-chart article has no Recipe JSON-LD; the parser must
    /// fail loudly so AC-1.7 can blocklist it. CL-9 / CL-10 lean on this.
    @Test func nonRecipeFixtureFailsWithNotFound() throws {
        let html = try loadFixture("non-recipe")
        #expect(throws: JSONLDRecipeParser.Error.notFound) {
            _ = try JSONLDRecipeParser.parse(
                html: html,
                merging: Self.placeholderListItem,
                canonicalURL: Self.placeholderURL
            )
        }
    }

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> String {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "html"),
            "Fixture \(name).html not found in test bundle"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static let placeholderListItem = RecipeListItem(
        id: 0,
        title: "<fixture>",
        excerpt: "<fixture>",
        heroImage: nil,
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
        totalTimeDisplay: nil
    )

    private static let placeholderURL =
        URL(string: "https://www.dutchovendaddy.com/fixture/") ?? URL(filePath: "/dev/null")
}
