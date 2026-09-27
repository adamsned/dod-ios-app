import DODDomain
import Foundation

// DUT-1339 — the findability half of the Saved-tab view model: the title
// search + the type/state filter chips, composed on top of the collection
// shelf selection (``collectionScopedRecipes``). Kept in an extension so the
// core `SavedViewModel` stays under the file-length cap. (Stored state —
// `searchText`, `typeFilter` — lives on the class itself, since `@Observable`
// can only track stored properties declared there.)
extension SavedViewModel {

    /// DUT-1339 — the type/state filter a chip selects. Each case is a single
    /// word so its Title Case control label is the raw value verbatim.
    public enum SavedTypeFilter: String, CaseIterable, Sendable {
        /// No filter — every saved item (recipes AND articles).
        case all
        /// `Recipe.isArticle == false`.
        case recipes
        /// `Recipe.isArticle == true`.
        case articles
        /// Desserts (id in ``SavedViewModel/dessertIDs``, DUT-1339 / DUT-325).
        case desserts
        /// Downloaded for offline use (id in ``SavedViewModel/downloadedIDs``).
        case downloaded

        /// Title Case chip label (single words, so already Title Case).
        public var title: String {
            switch self {
            case .all: return "All"
            case .recipes: return "Recipes"
            case .articles: return "Articles"
            case .desserts: return "Desserts"
            case .downloaded: return "Downloaded"
            }
        }

        /// Whether a recipe passes this filter. `downloadedIDs` / `dessertIDs`
        /// are threaded in because those sets live on the view model, not on the
        /// partial recipe the Saved tab renders (which carries no categories).
        func matches(_ recipe: Recipe, downloadedIDs: Set<Int>, dessertIDs: Set<Int>) -> Bool {
            switch self {
            case .all: return true
            case .recipes: return !recipe.isArticle
            case .articles: return recipe.isArticle
            case .desserts: return dessertIDs.contains(recipe.id)
            case .downloaded: return downloadedIDs.contains(recipe.id)
            }
        }
    }

    /// The recipes to show in the grid/list: the collection-scoped set narrowed
    /// by the active ``typeFilter`` and then by the ``searchText`` title match.
    /// All three compose — they narrow together — and every input is already in
    /// memory, so this stays a pure client-side filter (no fetch).
    public var displayedRecipes: [Recipe] {
        var result = collectionScopedRecipes.filter {
            typeFilter.matches($0, downloadedIDs: downloadedIDs, dessertIDs: dessertIDs)
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { $0.title.range(of: query, options: .caseInsensitive) != nil }
        }
        return result
    }

    /// True when the user has narrowed the list with search or a type filter
    /// (i.e. NOT the plain "All Saved" / "All" default). ``SavedView`` uses this
    /// to show the "no matches" empty state — distinct from an empty collection.
    public var isFilteringActive: Bool {
        typeFilter != .all
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
