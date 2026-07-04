import DODDomain
import DODSupport
import Foundation
import Observation

/// The selection state behind ``AddToShoppingListSheet`` (DUT-535 — pick which
/// of a recipe's ingredients to add to the Shopping List).
///
/// Extracted from the view so the checklist logic — candidate rows, per-row
/// toggle, the aisle grouping, the live selected-count, and the "add the chosen
/// subset" build — is unit-testable without a SwiftUI host (matches the
/// ``ShoppingListViewModel`` split). The view binds to it as `@State`.
///
/// **Candidates (CL-77):** the candidate rows are built through the shared
/// ``ShoppingListViewModel/rows(from:)`` (the same explode-and-classify the
/// whole-recipe add + the picker use), so a subset-appended row is
/// byte-identical to one added the other ways.
///
/// **All-selected default (DUT-535):** every candidate starts selected, so the
/// sheet's confirm reproduces the old add-all behavior with a single tap; the
/// cook only touches rows they want to drop.
@Observable
@MainActor
public final class AddToShoppingListSelection {

    /// One aisle group of candidate rows, in `Aisle.allCases` order (matching
    /// the Shopping List's section order — Produce → Meat → Dairy → Pantry →
    /// Spices → Other), omitting aisles with no candidate.
    public struct Group: Identifiable, Sendable {
        public var id: IngredientAisleClassifier.Aisle { aisle }
        public let aisle: IngredientAisleClassifier.Aisle
        public let items: [ShoppingListViewModel.Item]
    }

    /// Every candidate row (the recipe's exploded + classified ingredient
    /// rows), in insertion order.
    public let candidates: [ShoppingListViewModel.Item]

    /// The ids of the rows currently selected (checked). Starts as every
    /// candidate id (all-selected default).
    public private(set) var selectedIDs: Set<UUID>

    /// Build the selection from a recipe's ingredients. Explodes + classifies
    /// via ``ShoppingListViewModel/rows(from:)`` (CL-77), then selects all.
    public convenience init(recipe: Recipe) {
        self.init(candidates: ShoppingListViewModel.rows(from: [recipe]))
    }

    /// Designated init — takes pre-built candidate rows AS-IS and selects them
    /// all. Used by ``init(recipe:)`` and by tests (which can pass fixed rows).
    public init(candidates: [ShoppingListViewModel.Item]) {
        self.candidates = candidates
        self.selectedIDs = Set(candidates.map(\.id))
    }

    // MARK: - Derived render model

    /// The candidate rows grouped into aisle sections in store-walk order
    /// (`Aisle.allCases` declaration order), omitting empty aisles — mirrors
    /// ``ShoppingListViewModel/sections``.
    public var groups: [Group] {
        let grouped = Dictionary(grouping: candidates, by: \.aisle)
        return IngredientAisleClassifier.Aisle.allCases.compactMap { aisle in
            guard let rows = grouped[aisle], !rows.isEmpty else { return nil }
            return Group(aisle: aisle, items: rows)
        }
    }

    /// Live count of selected rows — drives the "Add N items" confirm label and
    /// its disabled-at-zero state.
    public var selectedCount: Int {
        selectedIDs.count
    }

    /// True when every candidate is selected (drives the Select All / None
    /// toggle's state + label).
    public var isAllSelected: Bool {
        !candidates.isEmpty && selectedIDs.count == candidates.count
    }

    /// Whether a specific row is currently selected.
    public func isSelected(_ item: ShoppingListViewModel.Item) -> Bool {
        selectedIDs.contains(item.id)
    }

    // MARK: - Mutations

    /// Flip a row's selection.
    public func toggle(_ item: ShoppingListViewModel.Item) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    /// Select every candidate (Select All) when not already all-selected;
    /// otherwise clear the selection (Select None). A single toolbar toggle.
    public func toggleSelectAll() {
        if isAllSelected {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(candidates.map(\.id))
        }
    }

    /// The selected candidate rows in candidate order (what the confirm appends).
    public var selectedRows: [ShoppingListViewModel.Item] {
        candidates.filter { selectedIDs.contains($0.id) }
    }
}
