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
// `SubstitutionResult` / `IngredientSubstitution` / `RecipeContext` /
// `SubstitutionReason` value types. FoundationModels is never imported into
// DODFeatureSaved — the Live model impl is a leaf package the App injects.
extension ShoppingListViewModel {

    /// The substitution surface's state machine. Drives ``ShoppingListView``'s
    /// sheet: `.idle` keeps it dismissed; `.pickingReason` shows the reason chips
    /// + disclaimers before any model runs; `.loading` shows a spinner; `.loaded`
    /// shows the ``SubstitutionResult`` (options to pick from, a "leave it out"
    /// note, or a "not a good fit" explanation); `.notFound` shows the graceful
    /// "no substitute found" copy. Every non-idle case carries the row's `itemID`
    /// (so Apply targets the right row) and the target `ingredient` (so the sheet
    /// titles itself); the loading/loaded cases also carry the picked `reason` so
    /// the sheet can raise the allergy warning + stronger haptic on the result.
    public enum SubstitutionState: Equatable, Sendable {
        case idle
        case pickingReason(itemID: UUID, ingredient: String)
        case loading(itemID: UUID, ingredient: String, reason: SubstitutionReason?)
        case loaded(itemID: UUID, ingredient: String, reason: SubstitutionReason?, result: SubstitutionResult)
        case notFound(itemID: UUID, ingredient: String)

        /// The ingredient the sheet is about, if any.
        public var ingredient: String? {
            switch self {
            case .idle: return nil
            case .pickingReason(_, let ingredient),
                .loading(_, let ingredient, _),
                .loaded(_, let ingredient, _, _),
                .notFound(_, let ingredient):
                return ingredient
            }
        }

        /// The row this substitution targets, if any.
        public var itemID: UUID? {
            switch self {
            case .idle: return nil
            case .pickingReason(let id, _),
                .loading(let id, _, _),
                .loaded(let id, _, _, _),
                .notFound(let id, _):
                return id
            }
        }

        /// The reason chosen for this run, if the run has started.
        public var reason: SubstitutionReason? {
            switch self {
            case .loading(_, _, let reason), .loaded(_, _, let reason, _): return reason
            case .idle, .pickingReason, .notFound: return nil
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

    /// Generate a suggestion for the sheet's current ingredient, tailored to the
    /// dish (recipe-aware) and to `reason` (`nil` = general pantry swap). Drives
    /// `.loading` → `.loaded` / `.notFound`. Callable from `.pickingReason` (first
    /// run) or from a result state (re-generate with a different reason). The
    /// underlying service never throws — a `nil` result becomes `.notFound`.
    public func generateSubstitution(reason: SubstitutionReason?) async {
        guard let intelligence, intelligence.isAvailable else { return }
        guard let itemID = substitution.itemID, let ingredient = substitution.ingredient else { return }
        substitution = .loading(itemID: itemID, ingredient: ingredient, reason: reason)
        let context = recipeContext(for: itemID)
        let result = await intelligence.suggestSubstitution(for: ingredient, in: context, reason: reason)
        // Guard a stale completion: if the user dismissed or started a different
        // lookup while this awaited, don't clobber the newer state.
        guard case .loading(let pendingID, let pending, _) = substitution,
            pendingID == itemID, pending == ingredient
        else { return }
        if let result {
            substitution = .loaded(itemID: itemID, ingredient: ingredient, reason: reason, result: result)
        } else {
            substitution = .notFound(itemID: itemID, ingredient: ingredient)
        }
    }

    /// Apply one chosen substitute option: replace the target row's ingredient
    /// line in place (same id + recipe, re-classified aisle), persist, and
    /// dismiss. No-op unless the sheet is `.loaded` and the row still exists.
    public func applySubstitution(_ option: IngredientSubstitution) {
        guard case .loaded(let itemID, _, _, let result) = substitution,
            case .options = result.verdict
        else { return }
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            substitution = .idle
            return
        }
        let old = items[index]
        items[index] = Item(
            id: old.id,
            ingredientText: option.substitute,
            recipeTitle: old.recipeTitle,
            aisle: IngredientAisleClassifier.classify(option.substitute)
        )
        rebuildVisibleItems()
        persist()
        substitution = .idle
    }

    /// Act on an "omit" verdict — leave the ingredient out: remove the target row
    /// from the list, persist, and dismiss. No-op unless `.loaded` with an
    /// ``SubstitutionResult/Verdict/omit`` result and the row still exists.
    public func omitIngredient() {
        guard case .loaded(let itemID, _, _, let result) = substitution,
            case .omit = result.verdict
        else { return }
        items.removeAll { $0.id == itemID }
        rebuildVisibleItems()
        persist()
        substitution = .idle
    }

    /// Dismiss the substitution sheet (return to `.idle`).
    public func dismissSubstitution() {
        substitution = .idle
    }

    /// Build recipe-aware context for the target row: the dish title plus the
    /// other still-listed ingredient lines from the SAME recipe (per-recipe rows,
    /// CL-77, make sibling lines reachable). Lets the model weigh the ingredient's
    /// role in the actual dish rather than swapping it in isolation. `nil` if the
    /// row has vanished.
    private func recipeContext(for itemID: UUID) -> RecipeContext? {
        guard let target = items.first(where: { $0.id == itemID }) else { return nil }
        let siblings =
            items
            .filter { $0.recipeTitle == target.recipeTitle && $0.id != itemID }
            .map(\.ingredientText)
        return RecipeContext(recipeTitle: target.recipeTitle, otherIngredients: siblings)
    }
}
