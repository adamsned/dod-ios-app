#if os(iOS) && canImport(UIKit)

import XCTest
@testable import DODFeatureRecipeDetail

final class RecipeTentCardRendererTests: XCTestCase {

    @MainActor
    func testFilenameForSlug() {
        let recipe = Recipe(
            id: 1,
            slug: "test-recipe",
            title: "Test Recipe",
            description: "",
            prepTime: 0,
            cookTime: 0,
            totalTime: 0,
            servings: 0,
            ingredients: [],
            instructions: [],
            tags: [],
            hostName: "",
            hostAvatar: nil,
            image: nil
        )

        XCTAssertEqual(RecipeTentCardRenderer.filename(for: recipe), "test-recipe-tent-card.png")
    }

    @MainActor
    func testFilenameForEmptySlug() {
        let recipe = Recipe(
            id: 1,
            slug: "",
            title: "Test Recipe",
            description: "",
            prepTime: 0,
            cookTime: 0,
            totalTime: 0,
            servings: 0,
            ingredients: [],
            instructions: [],
            tags: [],
            hostName: "",
            hostAvatar: nil,
            image: nil
        )

        XCTAssertEqual(RecipeTentCardRenderer.filename(for: recipe), "recipe-tent-card.png")
    }

    @MainActor
    func testPngData() {
        let recipe = Recipe(
            id: 1,
            slug: "test-recipe",
            title: "Test Recipe",
            description: "",
            prepTime: 0,
            cookTime: 0,
            totalTime: 0,
            servings: 0,
            ingredients: [],
            instructions: [],
            tags: [],
            hostName: "",
            hostAvatar: nil,
            image: nil
        )

        let content = TentCardContent(recipe: recipe, hostName: "Sam")
        let data = RecipeTentCardRenderer.pngData(content: content)

        XCTAssertNotNil(data)
        XCTAssertEqual(data?.prefix(4).map { Array($0) }, [0x89, 0x50, 0x4E, 0x47])
    }

    @MainActor
    func testWriteFile() {
        let recipe = Recipe(
            id: 1,
            slug: "test-recipe",
            title: "Test Recipe",
            description: "",
            prepTime: 0,
            cookTime: 0,
            totalTime: 0,
            servings: 0,
            ingredients: [],
            instructions: [],
            tags: [],
            hostName: "",
            hostAvatar: nil,
            image: nil
        )

        let url = RecipeTentCardRenderer.writeFile(recipe: recipe, hostName: "Sam")
        XCTAssertNotNil(url)

        // Verify the file exists and clean up
        if let url = url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// DUT-977 — test that tent card sharing produces a valid file
    func testTentCardShareProducesFile() {
        let recipe = Recipe(
            id: 123,
            title: "Test Recipe",
            description: "A test recipe",
            canonicalURL: URL(string: "https://example.com/recipe/123")!,
            heroImage: nil,
            heroImageLargeURL: nil
        )

        let url = RecipeTentCardRenderer.writeFile(recipe: recipe, hostName: "Test Host")
        XCTAssertNotNil(url)

        // Verify the file exists and has content
        if let fileUrl = url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileUrl.path))
            // Check that it's a valid PDF (at least not empty)
            do {
                let fileSize = try FileManager.default.attributesOfItem(atPath: fileUrl.path)[.size] as? UInt64
                XCTAssertGreaterThan(fileSize ?? 0, 0)
            } catch {
                XCTFail("Could not check file size: \(error)")
            }
        }
    }
}

#endif
