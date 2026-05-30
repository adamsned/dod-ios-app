import DODDomain
import Foundation

/// Composable post-filters applied client-side after the REST + local
/// ingredient passes merge. We post-filter (rather than push filters into
/// the WP REST query) because (a) WP REST `posts` doesn't accept an
/// arbitrary total-time filter and (b) the local ingredient pass returns
/// raw recipe IDs, not category-tagged items — keeping the filter logic
/// in one place avoids two divergent code paths.
///
/// Spec trace: US-12 / AC-12.2 (filter chips), AC-12.3 (filters compose).
public struct SearchFilters: Equatable, Sendable {

    /// "All categories" when nil; otherwise scope to a single WP category ID.
    public var categoryID: Int?

    /// Minimum total cook time in SECONDS (inclusive). nil = no lower bound.
    ///
    /// CL-122 (T-644) replaced the `CookTimeBucket` enum with a true min/max
    /// range so the chip can express "30 min or more" / "30 min–1 hr" /
    /// any single point on the wheel-picker; see `CookTimeRangeSheet` for
    /// the surface and `CookTimeFormatter` for the canonical label format.
    public var cookTimeMinSeconds: Int?

    /// Maximum total cook time in SECONDS (inclusive). nil = no upper bound.
    public var cookTimeMaxSeconds: Int?

    /// When true, restrict results to recipes the user has opened recently
    /// (presence in the local cache via `lastViewedAt`). Surfaced as the
    /// "Recently viewed" toggle chip.
    public var recentlyViewedOnly: Bool

    public init(
        categoryID: Int? = nil,
        cookTimeMinSeconds: Int? = nil,
        cookTimeMaxSeconds: Int? = nil,
        recentlyViewedOnly: Bool = false
    ) {
        self.categoryID = categoryID
        self.cookTimeMinSeconds = cookTimeMinSeconds
        self.cookTimeMaxSeconds = cookTimeMaxSeconds
        self.recentlyViewedOnly = recentlyViewedOnly
    }

    /// True if every filter is at its default — used to skip the post-filter
    /// pass entirely (cheap path, no per-item allocation).
    public var isAllDefault: Bool {
        categoryID == nil
            && cookTimeMinSeconds == nil
            && cookTimeMaxSeconds == nil
            && !recentlyViewedOnly
    }

    /// True if either cook-time bound is set — used by the hydration path
    /// in `SearchViewModel.kickOffCookTimeHydrationIfNeeded(...)` so the
    /// fetch fires whenever the filter is active regardless of which side
    /// the user pinned on the wheel.
    public var hasCookTimeRange: Bool {
        cookTimeMinSeconds != nil || cookTimeMaxSeconds != nil
    }

    /// Apply the filters to a result set. `categoryIDsByRecipe` maps each
    /// recipe ID to its WP categories (sourced from the local cache).
    /// `recentlyViewedIDs` is the set of recipe IDs the user has opened.
    /// Missing entries in either map mean "unknown" — which we treat as a
    /// MISS for the corresponding filter (a safer default than admitting
    /// every uncategorized result).
    ///
    /// CL-122 (T-644): the cook-time predicate is now a true range —
    /// `(min ?? 0) <= totalSeconds <= (max ?? .max)`. Inverted range
    /// (min > max) silently returns empty since no totalSeconds can
    /// satisfy both predicates; the empty-results state handles the
    /// user-facing affordance.
    public func apply(
        to items: [RecipeListItem],
        categoryIDsByRecipe: [Int: [Int]],
        totalSecondsByRecipe: [Int: Int],
        recentlyViewedIDs: Set<Int>
    ) -> [RecipeListItem] {
        guard !isAllDefault else { return items }
        return items.filter { item in
            if let categoryID {
                guard categoryIDsByRecipe[item.id]?.contains(categoryID) == true else {
                    return false
                }
            }
            if hasCookTimeRange {
                guard let seconds = totalSecondsByRecipe[item.id] else {
                    return false
                }
                if let min = cookTimeMinSeconds, seconds < min { return false }
                if let max = cookTimeMaxSeconds, seconds > max { return false }
            }
            if recentlyViewedOnly {
                guard recentlyViewedIDs.contains(item.id) else {
                    return false
                }
            }
            return true
        }
    }
}

// MARK: - CookTimeFormatter

/// Pure helper that turns a total-seconds duration into the canonical
/// user-facing label format shared by the wheel rows in
/// ``CookTimeRangeSheet`` and the chip label in ``SearchView``. Keeping
/// both consumers on one helper means the format never drifts between
/// the picker and the chip the picker mutates.
///
/// CL-122 / REG-31 (T-644): **no `≤` / `≥` symbols anywhere** in cook-time
/// copy — the format is plain duration text (`"30 min"`, `"1 hr"`,
/// `"1 hr 30 min"`, `"4 hr"`). Nil / zero is caller-handled: the chip
/// shows "Any time" when both bounds are nil and the wheel renders an
/// "Any" sentinel entry rather than calling the formatter with zero.
public enum CookTimeFormatter {

    /// Format `seconds` (total cook time) as a human-readable duration.
    /// Inputs the helper is contracted to handle:
    /// - `< 3600` → `"<minutes> min"` (e.g. `"30 min"`).
    /// - `== 3600` → `"1 hr"`.
    /// - multiples of 3600 → `"<hours> hr"` (e.g. `"2 hr"`).
    /// - otherwise → `"<hours> hr <minutes> min"` (e.g. `"1 hr 30 min"`).
    public static func label(seconds: Int) -> String {
        if seconds < 3600 {
            return "\(seconds / 60) min"
        }
        let hours = seconds / 3600
        let leftoverMinutes = (seconds % 3600) / 60
        if leftoverMinutes == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(leftoverMinutes) min"
    }
}

// MARK: - Chip label

/// Compute the cook-time chip's user-facing label from the current
/// `SearchFilters.cookTimeMinSeconds` / `cookTimeMaxSeconds` pair. Pure
/// function so the four-state shape (both nil / only min / only max /
/// both / min == max) is unit-testable without touching the view.
///
/// CL-122 / REG-31 (T-644): the four label states are pinned at the
/// helper level. The strings are the chip's source of truth and are
/// asserted by `SearchFiltersTests.cookTimeChipLabelComputesAllFourStates`.
public func cookTimeChipLabel(min: Int?, max: Int?) -> String {
    switch (min, max) {
    case (nil, nil):
        return "Any time"
    case (let minSeconds?, nil):
        return "\(CookTimeFormatter.label(seconds: minSeconds)) or more"
    case (nil, let maxSeconds?):
        return "\(CookTimeFormatter.label(seconds: maxSeconds)) or less"
    case (let minSeconds?, let maxSeconds?):
        if minSeconds == maxSeconds {
            return CookTimeFormatter.label(seconds: minSeconds)
        }
        return "\(CookTimeFormatter.label(seconds: minSeconds))–\(CookTimeFormatter.label(seconds: maxSeconds))"
    }
}
