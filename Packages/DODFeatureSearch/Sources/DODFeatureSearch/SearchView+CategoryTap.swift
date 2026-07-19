import DODDomain

/// The "Try Searching" pill tap-routing decision, split from
/// `SearchView.swift` to keep that file under SwiftLint's `file_length` cap.
extension SearchView {

    /// What tapping a "Try Searching" pill for `category` should do
    /// (DUT-1233).
    enum CategoryTapAction: Equatable {
        /// "Latest Recipes" (US-29 / CL-106 / T-637) — a bespoke feed fetch
        /// via `SearchViewModel.surfaceLatestRecipes()`, not a category
        /// browse. A literal full-text search for the phrase "Latest
        /// Recipes" returns garbage (the phrase appears in many unrelated
        /// articles' boilerplate).
        case surfaceLatestRecipes
        /// Every other category — browse that category's recipes via
        /// `onSelectCategory`, exactly like the "Categories" section's rows
        /// already do.
        ///
        /// DUT-1233 bug this replaces: the pill used to run a literal
        /// full-text search for the category's NAME
        /// (`selectCuratedSuggestion(category.name)`). That's correct for a
        /// genuinely searchable topic keyword ("Brisket", "Sweet Potato"),
        /// but wrong for a curated collection-style category name that never
        /// appears literally in any individual recipe's title — confirmed
        /// live against the WP category list: "Fall Favorites", "Memorial
        /// Day Recipes", "Easter Recipes", "Holiday Recipes", "Thanksgiving
        /// Recipes", "Cinco De Mayo", and "New Year's Eve Recipes" all share
        /// this shape, so a literal search for any of them returned "No
        /// recipes match" — the exact same failure mode "Latest Recipes" had
        /// before it got its own special case, just never fixed for the
        /// other collection-style categories.
        case browseCategory
    }

    /// Pure decision so the DUT-1233 fix (and the "Latest Recipes" carve-out
    /// it preserves) is unit-testable without a SwiftUI host.
    static func categoryTapAction(for category: DODDomain.Category) -> CategoryTapAction {
        SearchViewModel.isLatestRecipesCategory(category) ? .surfaceLatestRecipes : .browseCategory
    }
}
