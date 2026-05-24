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
        case .feed: "Recipes"
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
        // The in-recipe Save heart in RecipeDetailView is intentionally
        // **not** updated here (AC-16.3).
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
