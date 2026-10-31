import DODDomain
import DODFeatureRecipeDetail
import Foundation
import XCTest

@testable import DODApp

/// DUT-1014: the on-screen ingredient entity and its query.
@MainActor
final class IngredientEntityTests: XCTestCase {

    private var addedIDs: [UUID] = []

    override func tearDown() async throws {
        for id in addedIDs { OnscreenIngredients.shared.disappear(id: id) }
        addedIDs = []
        try await super.tearDown()
    }

    private func appear(_ text: String, recipeTitle: String = "Bread") -> OnscreenIngredients.Entry {
        let item = RecipeListItem(
            id: 42,
            title: recipeTitle,
            excerpt: "",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let recipe = Recipe(listItem: item)
        let entry = OnscreenIngredients.Entry.make(
            recipe: recipe,
            ingredient: RecipeIngredient(text: text),
            displayText: text
        )
        OnscreenIngredients.shared.appear(entry)
        addedIDs.append(entry.id)
        return entry
    }

    func test_suggestedEntities_containsOnscreenIngredient() async throws {
        let entry = appear("2 cups Flour")
        let suggested = try await IngredientEntityQuery().suggestedEntities()
        XCTAssertTrue(suggested.contains { $0.id == entry.id })
    }

    func test_entitiesForIdentifiers_returnsIt() async throws {
        let entry = appear("2 cups Flour")
        let found = try await IngredientEntityQuery().entities(for: [entry.id])
        XCTAssertEqual(found.map(\.id), [entry.id])
        XCTAssertEqual(found.first?.text, "2 cups Flour")
        XCTAssertEqual(found.first?.recipeTitle, "Bread")
    }

    func test_entitiesMatching_isCaseInsensitive() async throws {
        let entry = appear("2 cups Flour")
        let found = try await IngredientEntityQuery().entities(matching: "flour")
        XCTAssertTrue(found.contains { $0.id == entry.id })
        let none = try await IngredientEntityQuery().entities(matching: "zzz")
        XCTAssertFalse(none.contains { $0.id == entry.id })
    }
}
