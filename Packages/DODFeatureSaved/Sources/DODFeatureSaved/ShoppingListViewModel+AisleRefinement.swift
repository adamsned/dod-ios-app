import DODIntelligence
import DODSupport
import Foundation

// DUT-1006: on-device LLM fallback for rows the static keyword map left in
// `.other`. VM talks only to the DODIntelligenceService protocol.
extension ShoppingListViewModel {

    /// Re-classify every `.other` row via `intelligence`. Rows are rebuilt with the
    /// same `id`, text and recipe title so checked / already-have state survives.
    /// A `nil` verdict or `.other` leaves the row untouched. No-op without a service
    /// or when the service is unavailable.
    public func refineOtherAisles() async {
        guard let intelligence, intelligence.isAvailable else { return }
        let pending = items.filter { $0.aisle == .other }
        guard !pending.isEmpty else { return }
        var verdicts: [UUID: IngredientAisleClassifier.Aisle] = [:]
        for item in pending {
            if let aisle = await intelligence.classifyAisle(item.ingredientText), aisle != .other {
                verdicts[item.id] = aisle
            }
        }
        guard !verdicts.isEmpty else { return }
        items = items.map { item in
            guard let aisle = verdicts[item.id] else { return item }
            return Item(
                id: item.id,
                ingredientText: item.ingredientText,
                recipeTitle: item.recipeTitle,
                aisle: aisle
            )
        }
        rebuildVisibleItems()
        persist()
    }
}
