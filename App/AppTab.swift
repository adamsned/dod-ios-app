/// Top-level tab identifier.
///
/// Case order is the **single source of truth** for the bottom tab-bar
/// order. Reordering here changes what the user sees; see AC-16.1 / CL-25.
/// The visual order is **Recipes → Saved → Cooking Tools → Search** — the
/// Categories tab was folded into Search in T-800 (CL-194 / DUT-113), and the
/// Grocery List + Settings tabs were retired in T-912 (CL-306 / DUT-551): the
/// Shopping List folded into the new **Cooking Tools** hub and Settings moved
/// to a header gear button.
enum AppTab: Hashable, CaseIterable, Identifiable {
    case feed
    case saved
    // T-912 / DUT-551 (CL-306) — the **Cooking Tools** hub, a first-class
    // destination that lists every utility in meal-making order (Your First
    // Cookout → Shopping List → Heat Coach → Cook Mode → Cooking Journal → Buy
    // BuzzyWaxx). It REPLACES the retired `.grocery` (Grocery List) tab — the
    // Shopping List is now a pushed destination inside this hub — and the
    // retired `.settings` tab (Settings moved to a header gear button). The
    // storage / deep-link keys the old Grocery tab used (`dod.shoppingList.v1`,
    // `dod://shopping-list`) are UNCHANGED; only the entry surface moved.
    case cookingTools
    case search

    var id: Self { self }

    /// Full screen-header title. Drives `FeedView.navigationTitle` (and
    /// the corresponding nav titles for every other tab) per US-37 /
    /// AC-37.1.
    ///
    /// **Read `tabLabel` — not `title` — for the bottom-tab `Label(...)`
    /// declaration.** The two split in T-660 / CL-65: a nav-bar title
    /// can wrap to a second line on small Dynamic Type sizes, but a
    /// tab-bar item has a fixed ~80pt width and truncates anything
    /// longer than ~10 characters into "Recipes & Arti...". The split
    /// preserves both the full-content semantics in the header and the
    /// short readable label at the bottom of the screen.
    var title: String {
        switch self {
        // US-37 / AC-37.1 (T-640, 2026-05-27): "Recipes" → "Recipes & Articles".
        // Communicates that the tab surfaces both WPRM-instrumented recipes
        // AND article-style posts (e.g. roundup posts) that route through
        // `ArticleDetailView` per CL-63. **T-660 / CL-65 (2026-05-27):**
        // the bottom-tab label was split off into `tabLabel` below
        // because "Recipes & Articles" truncates at the tab-bar's ~80pt
        // width on standard iPhone widths. `title` continues to drive
        // `FeedView.navigationTitle`. The telemetry name
        // (`telemetryName`, AC-16.4) is unchanged to preserve funnel
        // comparisons across both renames.
        case .feed: "Recipes & Articles"
        case .search: "Search"
        case .saved: "Saved"
        // T-912 / DUT-551 (CL-306) — the hub header + `DODScreenHeader` read the
        // full "Cooking Tools"; the bottom-tab label is the shorter "Tools"
        // (`tabLabel`) so it doesn't truncate the ~80pt tab slot (reuses the
        // `.feed` split precedent).
        case .cookingTools: "Cooking Tools"
        }
    }

    /// Short label used by the bottom tab bar (`Label(...)` inside
    /// `.tabItem { }` in `RootView.phoneTabs`). For most tabs this
    /// matches `title`. For `.feed` the tab bar gets the shorter
    /// "Recipes" while the screen header keeps the full "Recipes &
    /// Articles" — see T-660 / CL-65 for the rationale (tab-bar items
    /// have ~80pt fixed width and truncate "Recipes & Articles" to
    /// "Recipes & Arti..." on standard iPhone widths). The short label
    /// matches the pre-T-640 wording, which is unambiguously paired
    /// with the `house` glyph on the bottom bar; the content semantics
    /// (recipes + articles) are still surfaced by the screen-header
    /// `navigationTitle`.
    var tabLabel: String {
        switch self {
        // T-660 / CL-65: short label for the bottom tab bar. Matches
        // the pre-T-640 wording; the full "Recipes & Articles" still
        // drives `FeedView.navigationTitle`.
        case .feed: "Recipes"
        case .search: "Search"
        case .saved: "Saved"
        // T-912 / DUT-551 (CL-306) — short "Tools" for the ~80pt tab slot;
        // "Cooking Tools" (~13 chars) would truncate. The full name lives in
        // `title` (the hub's `DODScreenHeader`), mirroring `.feed`'s split.
        case .cookingTools: "Tools"
        }
    }

    /// SF Symbol name for the tab item. SwiftUI's `Label(systemImage:)`
    /// applied to a `TabView` tab automatically swaps to the `.fill`
    /// variant on selection (see CL-24) — no custom selection handling
    /// needed here.
    var systemImage: String {
        switch self {
        case .feed: "house"
        case .search: "magnifyingglass"
        // T-912 / DUT-551 (CL-306) — `frying.pan` (outline) unselected,
        // `frying.pan.fill` selected; SwiftUI's tab styling swaps to the filled
        // variant automatically. Matches the glyph the retired Cooking Tools
        // menu used.
        case .cookingTools: "frying.pan"
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
        case .search: "search"
        case .saved: "saved"
        // T-912 / DUT-551 (CL-306) — telemetry name is the stable code
        // identifier "cooking_tools" (added to the constitution §9 allowlist).
        // The retired `grocery` / `settings` tokens are historical (no longer
        // emitted from the tab path).
        case .cookingTools: "cooking_tools"
        }
    }
}
