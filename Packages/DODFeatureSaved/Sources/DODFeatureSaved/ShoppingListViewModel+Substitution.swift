import DODIntelligence
import Foundation

// v2 on-device AI (1/n) — the Shopping List ingredient-substitution flow, split
// out of `ShoppingListViewModel.swift` to keep that file under the SwiftLint
// 400-line `file_length` cap. The stored `intelligence` seam + the observed
// `substitution` state live in the main class body (they must, for `@Observable`
// tracking); the state machine + request flow live here.
//
// Boundary: this depends only on the DODIntelligence PROTOCOL + the plain
// `IngredientSubstitution` value type. FoundationModels is never imported into
// DODFeatureSaved — the Live model impl is a leaf package the App injects.
extension ShoppingListViewModel {

    /// The substitution surface's state machine. Drives
    /// ``ShoppingListView``'s sheet: `.idle` keeps it dismissed; `.loading`
    /// shows a spinner; `.loaded` shows the suggestion; `.notFound` shows the
    /// graceful "no substitute found" copy. Each non-idle case carries the
    /// target ingredient so the sheet can title itself while awaiting.
    public enum SubstitutionState: Equatable, Sendable {
        case idle
        case loading(ingredient: String)
        case loaded(ingredient: String, substitution: IngredientSubstitution)
        case notFound(ingredient: String)

        /// The ingredient the sheet is about, if any — used for the sheet title
        /// in every non-idle state.
        public var ingredient: String? {
            switch self {
            case .idle: return nil
            case .loading(let ingredient),
                .loaded(let ingredient, _),
                .notFound(let ingredient):
                return ingredient
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

    /// Request a substitution for `item`, driving the ``substitution`` state
    /// through `.loading` → `.loaded` / `.notFound`. No-op (leaves state
    /// `.idle`) when no model is available, so a spurious call on an
    /// unsupported device can't open an empty sheet. The underlying service
    /// never throws — a `nil` result (unavailable, model error, or guardrail
    /// rejection) becomes the graceful `.notFound` state.
    public func requestSubstitution(for item: Item) async {
        guard let intelligence, intelligence.isAvailable else { return }
        let ingredient = item.ingredientText
        substitution = .loading(ingredient: ingredient)
        let result = await intelligence.suggestSubstitution(for: ingredient)
        // Guard against a stale completion: if the user dismissed or started a
        // different lookup while this awaited, don't clobber the newer state.
        guard case .loading(let pending) = substitution, pending == ingredient else { return }
        if let result {
            substitution = .loaded(ingredient: ingredient, substitution: result)
        } else {
            substitution = .notFound(ingredient: ingredient)
        }
    }

    /// Dismiss the substitution sheet (return to `.idle`).
    public func dismissSubstitution() {
        substitution = .idle
    }
}
