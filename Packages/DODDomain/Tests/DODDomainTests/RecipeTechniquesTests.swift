import XCTest

@testable import DODDomain

@available(iOS 16.0, *)
final class RecipeTechniquesTests: XCTestCase {
    func testRecipeTechniquesWithInstructions() throws {
        let recipe = Recipe(
            id: 1,
            slug: "test-recipe",
            title: "Test Recipe",
            excerpt: "A test recipe",
            canonicalURL: URL(string: "https://example.com")!,
            publishedAt: Date(),
            instructions: [
                RecipeInstruction(step: 1, text: "Sear the chicken."),
                RecipeInstruction(step: 2, text: "Bake 20 min."),
            ],
            kind: .recipe
        )

        XCTAssertEqual(recipe.techniques, [.sear, .bake])
    }

    func testRecipeTechniquesWithTitleOnly() throws {
        let recipe = Recipe(
            id: 2,
            slug: "test-recipe-2",
            title: "Braised Short Ribs",
            excerpt: "A braised short ribs recipe",
            canonicalURL: URL(string: "https://example.com")!,
            publishedAt: Date(),
            instructions: [],
            kind: .recipe
        )

        XCTAssertEqual(recipe.techniques, [.braise])
    }

    func testArticleTechniquesReturnsEmpty() throws {
        let recipe = Recipe(
            id: 3,
            slug: "test-article",
            title: "Braised Short Ribs",
            excerpt: "An article about braised short ribs",
            canonicalURL: URL(string: "https://example.com")!,
            publishedAt: Date(),
            instructions: [
                RecipeInstruction(step: 1, text: "Sear the chicken."),
                RecipeInstruction(step: 2, text: "Bake 20 min."),
            ],
            kind: .article
        )

        XCTAssertEqual(recipe.techniques, [])
    }
}
