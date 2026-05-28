import Foundation
import Testing

@testable import DODDomain

/// L1 coverage for ``ShoppingListItem`` — the domain-side value type
/// that mirrors the SwiftData `@Model` shape T-682 introduces.
///
/// Persistence behavior (SwiftData container round-trip, migration
/// stages, the `@Model` checksum story) is T-682's responsibility and
/// is NOT covered here — these tests only pin the value-type contract.
///
/// Spec trace: US-39 / AC-39.2 (insertion path produces these rows),
/// AC-39.5 (`isChecked` is the mutable flag), AC-39.8 (persistence
/// fields), CL-69 (per-recipe rows decision — the `recipeTitle`
/// captured-at-insertion-time field).
@Suite("ShoppingListItem value type") struct ShoppingListItemTests {

    /// JSON-Codable round-trip through every field — guards against
    /// silent decode-failure if `Aisle`'s raw-value Codable shape ever
    /// diverges from `ShoppingListItem`'s synthesized Codable shape.
    @Test func codableRoundTrip() throws {
        let original = ShoppingListItem(
            id: UUID(),
            recipeID: 12345,
            recipeTitle: "Dutch Oven Bourbon Berry Cake",
            ingredientText: "1 1/2 cups buttermilk",
            aisle: .dairy,
            isChecked: true,
            addedAt: Date(timeIntervalSinceReferenceDate: 1_234_567)
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShoppingListItem.self, from: encoded)
        #expect(decoded == original)
    }

    /// Hashable equality is value-based across every field — two rows
    /// with the same id + payload are equal; differing fields produce
    /// inequality. Tests both sides so a future contributor changing
    /// the synthesized `Hashable` conformance is forced to update the
    /// test.
    @Test func hashableEquality() {
        let id = UUID()
        let addedAt = Date(timeIntervalSinceReferenceDate: 99_999)
        let a = ShoppingListItem(
            id: id,
            recipeID: 1,
            recipeTitle: "Recipe A",
            ingredientText: "1 cup flour",
            aisle: .pantry,
            isChecked: false,
            addedAt: addedAt
        )
        let b = ShoppingListItem(
            id: id,
            recipeID: 1,
            recipeTitle: "Recipe A",
            ingredientText: "1 cup flour",
            aisle: .pantry,
            isChecked: false,
            addedAt: addedAt
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)

        var c = a
        c.isChecked = true
        #expect(c != a, "Mutating isChecked must change equality")
    }

    /// The convenience init populates `id`, `isChecked`, and `addedAt`
    /// with sensible defaults — call sites that only know the
    /// recipe-id + title + line + aisle shouldn't have to invent a
    /// UUID or pass `.now` manually.
    @Test func defaultInitializerFieldsArePopulated() {
        let before = Date.now
        let item = ShoppingListItem(
            recipeID: 42,
            recipeTitle: "Test Recipe",
            ingredientText: "1 tsp salt",
            aisle: .spices
        )
        let after = Date.now
        // id is a fresh UUID (non-nil per the value type's let).
        #expect(item.id.uuidString.isEmpty == false)
        // isChecked defaults to false (no row arrives pre-checked).
        #expect(item.isChecked == false)
        // addedAt defaults to .now — pin it inside the window the
        // test captures so the default isn't accidentally a literal.
        #expect(item.addedAt >= before)
        #expect(item.addedAt <= after)
        // Required fields round-trip verbatim.
        #expect(item.recipeID == 42)
        #expect(item.recipeTitle == "Test Recipe")
        #expect(item.ingredientText == "1 tsp salt")
        #expect(item.aisle == .spices)
    }
}
