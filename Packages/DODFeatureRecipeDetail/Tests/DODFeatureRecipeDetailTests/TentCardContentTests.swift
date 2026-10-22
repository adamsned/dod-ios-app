import DODDomain
import XCTest

@testable import DODFeatureRecipeDetail

final class TentCardContentTests: XCTestCase {

    func testInitWithId42AndHostSam() {
        // Arrange
        let recipe = Recipe(
            id: 42,
            slug: "test-recipe",
            title: "Test Recipe",
            excerpt: "Test excerpt",
            canonicalURL: URL(string: "https://example.com/recipe")!,
            publishedAt: Date()
        )

        // Act
        let content = TentCardContent(recipe: recipe, hostName: "Sam")

        // Assert
        XCTAssertEqual(content.dishName, "Test Recipe")
        XCTAssertEqual(content.byline, "Made by Sam with Dutch Oven Daddy")
        XCTAssertEqual(content.qrPayload, "dod://recipe/42")
    }

    func testInitWithNilHostAndEmptyHost() {
        // Arrange
        let recipe = Recipe(
            id: 42,
            slug: "test-recipe",
            title: "Test Recipe",
            excerpt: "Test excerpt",
            canonicalURL: URL(string: "https://example.com/recipe")!,
            publishedAt: Date()
        )

        // Act & Assert for nil host
        let content1 = TentCardContent(recipe: recipe, hostName: nil)
        XCTAssertEqual(content1.byline, "Made with Dutch Oven Daddy")

        // Act & Assert for empty host
        let content2 = TentCardContent(recipe: recipe, hostName: "  ")
        XCTAssertEqual(content2.byline, "Made with Dutch Oven Daddy")
    }

    func testInitWithIdZero() {
        // Arrange
        let recipe = Recipe(
            id: 0,
            slug: "test-recipe",
            title: "Test Recipe",
            excerpt: "Test excerpt",
            canonicalURL: URL(string: "https://example.com/recipe")!,
            publishedAt: Date()
        )

        // Act
        let content = TentCardContent(recipe: recipe, hostName: "Sam")

        // Assert
        XCTAssertEqual(content.dishName, "Test Recipe")
        XCTAssertEqual(content.byline, "Made by Sam with Dutch Oven Daddy")
        XCTAssertEqual(content.qrPayload, "https://example.com/recipe")
    }
}
