import DODDomain
import Foundation

/// US-29 amendment / CL-117 / T-639 → v2 Search overhaul (3/3): the "Try
/// Searching" pill slate. Split into an extension on `SearchViewModel` so
/// the main view-model file stays under SwiftLint's `file_length` (400-line)
/// cap — same pattern the `SearchViewModel+T637.swift` Latest-Recipes special
/// case uses.
///
/// **Wave 3 source swap:** the slate used to shuffle over the top-30 WP
/// *categories* (`topTrySlatePool`, now removed). It now shuffles over the
/// curated 100-term *search-term* pool in ``SearchTryChips/pool``, mapping
/// each raw term to a ``SearchTryChip`` (raw query + Title-Cased display).
/// "Latest Recipes" stays pinned first and special (it is NOT one of the 100
/// — see ``SearchTryChips/latestRecipes``).
///
/// The slate is computed once per cold launch via a shuffle over the pool,
/// **pinned-Latest-Recipes-first** + shuffled remainder. The
/// stable-within-session contract comes from caching the slate in
/// `cachedTrySlate` (the backing storage lives on the main type because
/// Swift forbids stored properties on extensions). Because the pool is a
/// constant 100-term array (never empty, independent of the async category
/// fetch), the cold-start cache race that T-640 / CL-118 guarded against no
/// longer exists — but the `count >= visibleCount` cache guard is kept as a
/// cheap defensive invariant.
extension SearchViewModel {

    /// The slate of pills the Search-tab idle "Try" section renders.
    /// Computed lazily on first access (cached in `cachedTrySlate`) so the
    /// shuffle fires exactly once per `SearchViewModel` lifetime — i.e. once
    /// per cold launch. Subsequent reads return the cached slate so the row
    /// is **stable within session** across `IdleSuggestionsView` re-creates
    /// (tab switches, navigation pushes/pops).
    ///
    /// The slate has a fixed visible count of `Self.trySlateVisibleCount`
    /// (= 10) with "Latest Recipes" always first; see `pickTrySlate(...)`
    /// for the pin-first + shuffle logic.
    public var displayedTrySlate: [SearchTryChip] {
        if let cached = cachedTrySlate, cached.count >= Self.trySlateVisibleCount {
            return cached
        }
        var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
        let slate = Self.pickTrySlate(
            from: SearchTryChips.pool,
            visibleCount: Self.trySlateVisibleCount,
            using: &rng
        )
        // Only lock the slate when it is a full result. With the constant
        // pool this is always true on the first read, but the guard keeps the
        // "never cache a degenerate short row" invariant that T-640 / CL-118
        // established.
        if slate.count >= Self.trySlateVisibleCount {
            cachedTrySlate = slate
        }
        return slate
    }

    /// WP category slugs excluded from the browse "Categories" list — junk
    /// categories that don't make for a useful browse target. Still consumed
    /// by `browseCategories` (`SearchViewModel+T799.swift`); the compare side
    /// is `.lowercased()` so the set entries themselves stay lowercase.
    /// T-641 / CL-119.
    static let excludedTryPoolSlugs: Set<String> = ["uncategorized"]

    /// Visible pill count for the "Try" slate — fixed across every cold
    /// launch so the layout never shifts. v2 Search overhaul (3/3) bumps this
    /// from 6 to 10 (1 pinned Latest Recipes + 9 shuffled from the 100-term
    /// pool) so the widened pool is felt on the idle page. `nonisolated` so
    /// the pure `pickTrySlate(...)` helper's L1 tests can reference it off the
    /// main actor (it is an immutable constant, so safe to share).
    public nonisolated static let trySlateVisibleCount: Int = 10

    /// Pure helper that produces the "Try" slate: pinned-Latest-Recipes-first
    /// + shuffle the remainder over the curated pool + deterministic top-up
    /// (repeat the shuffled tail) only if the pool is smaller than the
    /// requested count. With the 100-term pool the top-up never fires; it is
    /// retained for degenerate / test pools. Degrades to a single pinned pill
    /// when the pool is empty or `visibleCount` is 1.
    ///
    /// The `using rng:` seam lets unit tests pin "same seed + same pool =
    /// same slate" determinism — production passes a
    /// `SystemRandomNumberGenerator()` which is per-process-seeded by the
    /// kernel so cold launches differ without any extra wiring.
    public nonisolated static func pickTrySlate(
        from pool: [String],
        visibleCount: Int,
        using rng: inout any RandomNumberGenerator
    ) -> [SearchTryChip] {
        let pinned = SearchTryChips.latestRecipes
        guard visibleCount > 1 else { return [pinned] }
        guard !pool.isEmpty else { return [pinned] }
        var shuffled = pool
        shuffled.shuffle(using: &rng)
        var slate: [SearchTryChip] = [pinned]
        var index = 0
        // Deterministic top-up: if the pool has fewer than the non-pinned
        // slot count, repeat the shuffled-pool tail to fill — the same term
        // runs the same search, so a duplicate pill is functionally correct.
        while slate.count < visibleCount {
            slate.append(SearchTryChips.chip(for: shuffled[index % shuffled.count]))
            index += 1
        }
        return slate
    }

    /// Case-insensitive name match (or id-1590 fallback) against the "Latest
    /// Recipes" WP category. Still used by `browseCategories`
    /// (`SearchViewModel+T799.swift`) to drop the synthetic recency feed from
    /// the browse list (CL-106 / CL-107).
    nonisolated static func isLatestRecipesCategory(_ category: DODDomain.Category) -> Bool {
        category.id == 1590
            || category.name.localizedCaseInsensitiveCompare("Latest Recipes") == .orderedSame
    }
}
