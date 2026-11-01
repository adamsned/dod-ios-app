#if os(iOS) && canImport(UIKit)

import DODDomain
import XCTest
@testable import DODFeatureRecipeDetail

final class RecipeTentCardRendererTests: XCTestCase {

    private func makeRecipe(slug: String) -> Recipe {
        Recipe(
            id: 1,
            slug: slug,
            title: "Test Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://example.com/test-recipe")!,
            publishedAt: Date(timeIntervalSince1970: 0)
        )
    }

    @MainActor
    func testFilenameForSlug() {
        let recipe = makeRecipe(slug: "test-recipe")

        XCTAssertEqual(RecipeTentCardRenderer.filename(for: recipe), "test-recipe-tent-card.png")
    }

    @MainActor
    func testFilenameForEmptySlug() {
        let recipe = makeRecipe(slug: "")

        XCTAssertEqual(RecipeTentCardRenderer.filename(for: recipe), "recipe-tent-card.png")
    }

    @MainActor
    func testPngData() {
        let recipe = makeRecipe(slug: "test-recipe")

        let content = TentCardContent(recipe: recipe, hostName: "Sam")
        let data = RecipeTentCardRenderer.pngData(content: content)

        XCTAssertNotNil(data)
        XCTAssertEqual(Array(data?.prefix(4) ?? Data()), [0x89, 0x50, 0x4E, 0x47])
    }

    @MainActor
    func testWriteFile() {
        let recipe = makeRecipe(slug: "test-recipe")

        let url = RecipeTentCardRenderer.writeFile(recipe: recipe, hostName: "Sam")
        XCTAssertNotNil(url)

        // Verify the file exists and clean up
        if let url = url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            try? FileManager.default.removeItem(at: url)
        }
    }
}

#endif
