import DODDomain
import Foundation

/// US-16 / CL-193 / T-799 (DUT-112): the full browse-categories list that
/// feeds the Search idle view's "Categories" section. Split into an
/// extension on `SearchViewModel` so the main view-model file stays under
/// SwiftLint's `file_length` (400-line) cap — the same pattern the
/// `+T637` / `+T639` / `+Recents` extensions use.
extension SearchViewModel {

    /// Full browse list for the Search idle view's "Categories" section.
    /// Different job from the "Try" chips: the chips suggest an exact search
    /// (`displayedTrySlate` — top-by-count, rotating); this is the complete
    /// topic index for browsing a broad pocket of one topic. Real WP
    /// categories sorted by recipe count (meatiest topics first), excluding
    /// the synthetic "Latest Recipes" feed (id 1590, CL-106 — a recency
    /// feed, not a topic) and the junk slugs in `excludedTryPoolSlugs`
    /// ("uncategorized", CL-119), so every row is a genuine category a tap
    /// can open in `CategoryRecipesView`. Shares `availableCategories` with
    /// the Try slate, so it populates on the same `loadCategoriesIfNeeded()`
    /// fetch — no extra network call.
    public var browseCategories: [DODDomain.Category] {
        availableCategories
            .filter { $0.id != 1590 && !Self.excludedTryPoolSlugs.contains($0.slug.lowercased()) }
            .sorted { $0.count > $1.count }
    }
}
