import DODDomain
import Foundation

/// US-29 amendment / CL-117 / T-639: the rotating "Try" pill slate. Split
/// into an extension on `SearchViewModel` so the main view-model file
/// stays under SwiftLint's `file_length` (400-line) cap — same pattern
/// the `SearchViewModel+T637.swift` Latest-Recipes special case uses.
///
/// The slate is computed once per cold launch via a shuffle over a
/// widened top-30-by-count source pool, **pinned-Latest-Recipes-first**
/// + shuffled remainder + deterministic top-up if the pool is shrunk
/// below the visible count. The stable-within-session contract comes
/// from caching the slate in `_displayedTrySlate` (the backing storage
/// lives on the main type because Swift forbids stored properties on
/// extensions).
extension SearchViewModel {

    /// The wider source pool the rotation draws from. **Top-30 by recipe
    /// count** rather than the top-5 of `topCategorySuggestions` — gives
    /// the per-cold-launch shuffle a meaningful pool size without
    /// inventing a hand-maintained curated-extras list (dutchovendaddy.com's
    /// WP taxonomy has 30+ active categories so this is the natural
    /// ceiling). `topCategorySuggestions` stays for backward compat.
    public var topTrySlatePool: [DODDomain.Category] {
        Array(availableCategories.sorted { $0.count > $1.count }.prefix(Self.trySlatePoolSize))
    }

    /// The slate of pills the Search-tab idle "Try" section actually
    /// renders. Computed **once** on first access (lazy semantics via
    /// `_displayedTrySlate` backing) so the shuffle fires exactly once
    /// per `SearchViewModel` lifetime — i.e. once per cold launch.
    /// Subsequent reads return the cached slate so the row is **stable
    /// within session** across `IdleSuggestionsView` re-creates (tab
    /// switches, navigation pushes/pops).
    ///
    /// The slate has a fixed visible count of `Self.trySlateVisibleCount`
    /// (= 6) with "Latest Recipes" always first; see `pickTrySlate(...)`
    /// for the pin-first + shuffle + top-up + empty-pool logic.
    public var displayedTrySlate: [DODDomain.Category] {
        if let cached = cachedTrySlate {
            return cached
        }
        var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
        let slate = Self.pickTrySlate(
            from: topTrySlatePool,
            visibleCount: Self.trySlateVisibleCount,
            using: &rng
        )
        cachedTrySlate = slate
        return slate
    }

    /// Source-pool size for the rotation. Top-30-by-count covers
    /// dutchovendaddy.com's active WP categories with room to grow.
    static let trySlatePoolSize: Int = 30

    /// Visible pill count for the rotating Try slate — fixed across
    /// every cold launch so the layout never shifts. One pinned Latest
    /// Recipes + five shuffled = 6.
    public static let trySlateVisibleCount: Int = 6

    /// US-29 amendment / CL-117 / T-639: pure helper that produces the
    /// rotating Try slate. Pinned-Latest-Recipes-first + shuffle the
    /// remainder + top-up with deterministic repetition if the pool is
    /// shrunk below the requested count. Returns exactly `visibleCount`
    /// items in the common case; degrades to a single pinned pill when
    /// the pool is empty or visibleCount is 1 (safer than rendering an
    /// empty Try section because Latest Recipes is the single
    /// most-valuable affordance).
    ///
    /// The `using rng:` seam lets unit tests pin "same seed + same pool
    /// = same slate" determinism — production passes a
    /// `SystemRandomNumberGenerator()` which is per-process-seeded by
    /// the kernel so cold launches differ without any extra wiring.
    public nonisolated static func pickTrySlate(
        from pool: [DODDomain.Category],
        visibleCount: Int,
        using rng: inout any RandomNumberGenerator
    ) -> [DODDomain.Category] {
        let pinned = pool.first(where: isLatestRecipesCategory) ?? syntheticLatestRecipes
        guard visibleCount > 1 else { return [pinned] }
        let rotatable = pool.filter { !isLatestRecipesCategory($0) }
        guard !rotatable.isEmpty else { return [pinned] }
        var shuffled = rotatable
        shuffled.shuffle(using: &rng)
        // Deterministic top-up: if the rotation pool has fewer than the
        // non-pinned slot count, repeat the shuffled-pool tail to fill
        // — same category fires the same handler, so duplicate pills
        // are functionally correct, just visually repeated. Better than
        // a short row per the AC-29.7 guardrail.
        var slate: [DODDomain.Category] = [pinned]
        var index = 0
        while slate.count < visibleCount {
            slate.append(shuffled[index % shuffled.count])
            index += 1
        }
        return slate
    }

    /// Case-insensitive name match (or id-1590 fallback) against the
    /// "Latest Recipes" WP category. Mirrors the same check the
    /// `SearchView.onCategoryTap` discriminator + `IdleSuggestionsView`'s
    /// per-pill identifier use (CL-106 / CL-107).
    nonisolated static func isLatestRecipesCategory(_ category: DODDomain.Category) -> Bool {
        category.id == 1590
            || category.name.localizedCaseInsensitiveCompare("Latest Recipes") == .orderedSame
    }

    /// Synthesized fallback used when the source pool does not contain a
    /// Latest-Recipes entry (REST anomaly / cold start before
    /// `loadCategoriesIfNeeded` lands). Holds the pin contract from
    /// AC-29.7 unconditionally. The id + name + slug are the canonical
    /// values per CL-106 (T-637); `count: 0` is benign because the
    /// downstream consumer is the rendered pill row, not a sort.
    nonisolated static let syntheticLatestRecipes = DODDomain.Category(
        id: 1590,
        name: "Latest Recipes",
        slug: "latest-recipes",
        count: 0
    )
}
