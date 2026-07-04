import DODDomain
import DODFeatureSaved
import SwiftUI

/// DUT-536 — the root of the top-level **Grocery List** tab.
///
/// The Shopping List used to be reachable only by pushing inside the Saved tab
/// (the header cart / the `dod://shopping-list` deep link). This view hoists it
/// to its own tab: it renders ``ShoppingListView`` directly, opened to the
/// persisted list via the store-backed no-arg ``ShoppingListViewModel`` (which
/// auto-loads the saved snapshot from the App-Group ``ShoppingListStore`` — the
/// SAME store the Saved-hosted entry and the Recipe-Detail / Feed-card
/// "Add to Shopping List" flows write to, so there is exactly one list).
///
/// **Dependency composition (mirrors ``SavedView``).** ``ShoppingListView``'s
/// in-place recipe picker ("Build List" / "Add recipes") needs two things the
/// Saved tab already supplies:
///   1. the SAVED recipes to pick from — sourced from a ``SavedViewModel`` built
///      with the same `dependencies.savedDependencies()` seam SavedView uses,
///      refreshed on appear;
///   2. `hydrate` — `SavedViewModel.recipeWithIngredients`, which fetches +
///      parses + caches a picked recipe's ingredients on demand (a saved recipe
///      whose detail was never opened arrives with empty `ingredients`, which
///      would otherwise build ZERO rows — DUT-487).
///
/// The shopping-list logic itself is NOT duplicated — this is a thin composition
/// shell around the existing ``ShoppingListView`` + ``ShoppingListViewModel``.
struct GroceryTabRoot: View {

    /// Sources the pickable saved recipes + the `recipeWithIngredients`
    /// hydration seam. Built once from `dependencies.savedDependencies()` (the
    /// exact seam ``SavedView`` uses) and refreshed on appear.
    @State private var savedViewModel: SavedViewModel

    init(dependencies: AppDependencies) {
        _savedViewModel = State(
            initialValue: SavedViewModel(dependencies: dependencies.savedDependencies())
        )
    }

    var body: some View {
        ShoppingListView(
            // No-arg (store-backed) view model: auto-loads the persisted list
            // from the App-Group `ShoppingListStore` so the tab opens straight
            // to the cook's saved list (DUT-488). `.onAppear`'s
            // `reloadFromStore()` (inside `ShoppingListView`, DUT-534) keeps it
            // consistent with any external append.
            viewModel: ShoppingListViewModel(),
            // The saved recipes feed the in-list picker; refreshed below.
            recipes: savedViewModel.recipes,
            // DUT-487 — hydrate a picked recipe's ingredients before building
            // rows. Identical seam to `SavedView`.
            hydrate: { await savedViewModel.recipeWithIngredients($0) }
        )
        .task {
            // Load the saved recipes so the picker has something to choose from
            // (mirrors `SavedView`'s appear-time refresh). The Shopping List
            // itself renders immediately from its persisted snapshot; this only
            // populates the "Build List" / "Add recipes" source.
            await savedViewModel.refresh()
        }
    }
}
