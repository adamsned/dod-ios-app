/// Top-level tab identifier.
///
/// Case order is the **single source of truth** for the bottom tab-bar
/// order. Reordering here changes what the user sees; see AC-16.1 / CL-25.
/// The visual order is **Recipes → Categories → Saved → Search** (post-US-16).
enum AppTab: Hashable, CaseIterable, Identifiable {
    case feed
    case categories
    case saved
    case search

    var id: Self { self }

    var title: String {
        switch self {
        // US-37 / AC-37.1 (T-640, 2026-05-27): "Recipes" → "Recipes & Articles".
        // Communicates that the tab surfaces both WPRM-instrumented recipes
        // AND article-style posts (e.g. roundup posts) that route through
        // `ArticleDetailView` per CL-63. The bottom-tab label and the
        // `FeedView` nav title both consume this string; the telemetry name
        // (`telemetryName`, AC-16.4) is unchanged to preserve funnel
        // comparisons across the rename.
        case .feed: "Recipes & Articles"
        case .categories: "Categories"
        case .search: "Search"
        case .saved: "Saved"
        }
    }

    /// SF Symbol name for the tab item. SwiftUI's `Label(systemImage:)`
    /// applied to a `TabView` tab automatically swaps to the `.fill`
    /// variant on selection (see CL-24) — no custom selection handling
    /// needed here.
    var systemImage: String {
        switch self {
        case .feed: "house"
        case .categories: "square.grid.2x2"
        case .search: "magnifyingglass"
        // `bookmark` (outline) when unselected, `bookmark.fill` when
        // selected — SwiftUI's tab styling handles the swap. AC-16.2.
        // The in-recipe Save button in RecipeDetailView matches this
        // glyph too (post-T-380 / CL-38 — reverses AC-16.3's earlier
        // carve-out so the affordance is consistent across surfaces).
        case .saved: "bookmark"
        }
    }

    /// Stable identifier emitted in `screenView` telemetry. **Must not
    /// change** even when the visual ordering or icon does — it gates
    /// cross-change funnel comparisons. AC-16.4.
    var telemetryName: String {
        switch self {
        case .feed: "feed"
        case .categories: "categories"
        case .search: "search"
        case .saved: "saved"
        }
    }
}
