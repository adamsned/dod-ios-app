import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("PinnedCollectionWidgetPublisher mapping") struct PinnedCollectionWidgetPublisherTests {

    private func recipe(_ id: Int, hero: URL? = nil) -> Recipe {
        Recipe(
            id: id,
            slug: "r\(id)",
            title: "Recipe \(id)",
            excerpt: "",
            canonicalURL: URL(string: "https://example.com/r\(id)") ?? URL(fileURLWithPath: "/"),
            heroImage: hero,
            publishedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func collection() -> RecipeCollection {
        RecipeCollection(
            id: UUID(),
            name: "Weeknight",
            sortOrder: 0,
            createdAt: Date(timeIntervalSince1970: 0),
            recipeIDs: []
        )
    }

    @Test func capsRecipesButKeepsTrueCount() {
        let recipes = (1...8).map { recipe($0) }
        let col = collection()
        let out = PinnedCollectionWidgetPublisher.toSnapshotCollection(col, recipes: recipes)
        #expect(out.id == col.id)
        #expect(out.name == "Weeknight")
        #expect(out.totalCount == 8)
        #expect(out.recipes.count == PinnedCollectionsWidgetSnapshotConfig.maxRecipesPerCollection)
        #expect(out.recipes.first?.recipeID == 1)
    }

    @Test func mapsHeroImageToFilename() throws {
        let url = try #require(URL(string: "https://example.com/a.jpg"))
        let out = PinnedCollectionWidgetPublisher.toSnapshotCollection(
            collection(),
            recipes: [recipe(1, hero: url), recipe(2)]
        )
        #expect(out.recipes[0].heroImageFilename == WidgetImageBridge.filename(for: url))
        #expect(out.recipes[1].heroImageFilename == nil)
    }
}
