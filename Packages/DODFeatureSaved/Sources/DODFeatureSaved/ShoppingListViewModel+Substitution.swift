import DODIntelligence
import DODSupport
import Foundation

// v2 on-device AI — the Shopping List ingredient-substitution flow, split out of
// `ShoppingListViewModel.swift` to keep that file under the SwiftLint 400-line
// `file_length` cap. The stored `intelligence` seam + the observed
// `substitution` state live in the main class body (they must, for `@Observable`
// tracking); the state machine + request/apply flow live here.
//
// Boundary: this depends only on the DODIntelligence PROTOCOL + the plain
// `IngredientSubstitution` / `SubstitutionReason` value types. FoundationModels
// is never imported into DODFeatureSaved — the Live model impl is a leaf package
// the App injects.
extension ShoppingListViewModel {

    /// The substitution surface's state machine. Drives ``ShoppingListView``'s
    /// sheet: `.idle` keeps it dismissed; `.pickingReason` shows the reason
    /// chips before any model runs; `.loading` shows a spinner; `.loaded` shows
    /// the suggestion with an Apply button; `.notFound` shows the graceful
    /// "no substitute found" copy. Every non-idle case carries the row's `itemID`
    /// (so Apply replaces the right row) and the target `ingredient` (so the
    /// sheet can title itself).
    public enum SubstitutionState: Equatable, Sendable {
        case idle
        case pickingReason(itemID: UUID, ingredient: String)
        case loading(itemID: UUID, ingredient: String)
        case loaded(itemID: UUID, ingredient: String, substitution: IngredientSubstitution)
        case notFound(itemID: UUID, ingredient: String)

        /// The ingredient the sheet is about, if any.
        public var ingredient: String? {
            switch self {
            case .idle: return nil
            case .pickingReason(_, let ingredient),
                .loading(_, let ingredient),
                .loaded(_, let ingredient, _),
                .notFound(_, let ingredient):
                return ingredient
            }
        }

        /// The row this substitution targets, if any.
        public var itemID: UUID? {
            switch self {
            case .idle: return nil
            case .pickingReason(let id, _),
                .loading(let id, _),
                .loaded(let id, _, _),
                .notFound(let id, _):
                return id
            }
        }
    }

    /// `true` only when an on-device model is usable right now. The Shopping
    /// List shows the "Substitute" affordance ONLY when this is `true`, so
    /// unsupported devices (iOS 17-25, incapable hardware, no Apple
    /// Intelligence) never see a dead control.
    public var isSubstitutionAvailable: Bool {
        intelligence?.isAvailable ?? false
    }

    /// Open the substitution sheet for `item` on the reason-picking step. No-op
    /// (leaves state `.idle`) when no model is available, so a spurious call on
    /// an unsupported device can't open an empty sheet. The user picks a reason
    /// (or none) and then generates via ``generateSubstitution(reason:)``.
    public func beginSubstitution(for item: Item) {
        guard let intelligence, intelligence.isAvailable else { return }
        substitution = .pickingReason(itemID: item.id, ingredient: item.ingredientText)
    }

    /// Generate a suggestion for the sheet's current ingredient, tailored to
    /// `reason` (`nil` = general pantry swap). Drives `.loading` → `.loaded` /
    /// `.notFound`. Callable from `.pickingReason` (first run) or from a result
    /// state (re-generate with a different reason). The underlying service never
    /// throws — a `nil` result becomes the graceful `.notFound` state.
    public func generateSubstitution(reason: SubstitutionReason?) async {
        guard let intelligence, intelligence.isAvailable else { return }
        guard let itemID = substitution.itemID, let ingredient = substitution.ingredient else { return }
        substitution = .loading(itemID: itemID, ingredient: ingredient)
        let result = await intelligence.suggestSubstitution(for: ingredient, reason: reason)
        // Guard a stale completion: if the user dismissed or started a different
        // lookup while this awaited, don't clobber the newer state.
        guard case .loading(let pendingID, let pending) = substitution,
            pendingID == itemID, pending == ingredient
        else { return }
        if let result {
            substitution = .loaded(itemID: itemID, ingredient: ingredient, substitution: result)
        } else {
            substitution = .notFound(itemID: itemID, ingredient: ingredient)
        }
    }

    /// Apply the loaded suggestion: replace the target row's ingredient line in
    /// place (same id + recipe, re-classified aisle), persist, and dismiss. No-op
    /// unless `.loaded` and the row still exists.
    public func applySubstitution() {
        guard case .loaded(let itemID, _, let result) = substitution else { return }
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            substitution = .idle
            return
        }
        let old = items[index]
        items[index] = Item(
            id: old.id,
            ingredientText: result.substitute,
            recipeTitle: old.recipeTitle,
            aisle: IngredientAisleClassifier.classify(result.substitute)
        )
        rebuildVisibleItems()
        persist()
        substitution = .idle
    }

    /// Dismiss the substitution sheet (return to `.idle`).
    public func dismissSubstitution() {
        substitution = .idle
    }
}
