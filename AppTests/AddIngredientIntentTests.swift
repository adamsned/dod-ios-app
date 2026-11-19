import DODDomain
import DODFeatureRecipeDetail
import Foundation
import XCTest

@testable import DODApp

/// DUT-1014: the "add that to my list" intent's pure helpers.
@MainActor
final class AddIngredientIntentTests: XCTestCase {

    private typealias Intent = AddIngredientToShoppingListIntent

    private func makeEntry(_ text: String) -> OnscreenIngredients.Entry {
        let item = RecipeListItem(
            id: 42,
            title: "Bread",
            excerpt: "",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        return OnscreenIngredients.Entry.make(
            recipe: Recipe(listItem: item),
            ingredient: RecipeIngredient(text: text),
            displayText: text
        )
    }

    func test_dialogText_added() {
        XCTAssertEqual(
            Intent.dialogText(.added(count: 1), ingredient: "2 tbsp butter"),
            "Added 2 tbsp butter to your Shopping List."
        )
    }

    func test_dialogText_couldntLoad() {
        XCTAssertTrue(Intent.dialogText(.couldntLoad, ingredient: "butter").contains("couldn't"))
    }

    func test_entry_nilReturnsLatest() {
        let registry = OnscreenIngredients()
        registry.appear(makeEntry("2 cups flour"))
        let last = makeEntry("1 tsp salt")
        registry.appear(last)
        XCTAssertEqual(Intent.entry(for: nil, registry: registry)?.id, last.id)
    }

    func test_entry_namedReturnsThatEntry() {
        let registry = OnscreenIngredients()
        let first = makeEntry("2 cups flour")
        registry.appear(first)
        registry.appear(makeEntry("1 tsp salt"))
        let found = Intent.entry(for: IngredientEntity(entry: first), registry: registry)
        XCTAssertEqual(found?.id, first.id)
    }

    func test_entry_emptyRegistryReturnsNil() {
        XCTAssertNil(Intent.entry(for: nil, registry: OnscreenIngredients()))
    }
}
