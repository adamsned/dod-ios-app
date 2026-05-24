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

    /// Total-time bucket constraint, or nil for "Any".
    public var cookTime: CookTimeBucket?

    /// When true, restrict results to recipes the user has opened recently
    /// (presence in the local cache via `lastViewedAt`). Surfaced as the
    /// "Recently viewed" toggle chip.
    public var recentlyViewedOnly: Bool

    public init(
        categoryID: Int? = nil,
        cookTime: CookTimeBucket? = nil,
        recentlyViewedOnly: Bool = false
    ) {
        self.categoryID = categoryID
        self.cookTime = cookTime
        self.recentlyViewedOnly = recentlyViewedOnly
    }

    /// True if every filter is at its default — used to skip the post-filter
    /// pass entirely (cheap path, no per-item allocation).
    public var isAllDefault: Bool {
        categoryID == nil && cookTime == nil && !recentlyViewedOnly
    }

    /// Apply the filters to a result set. `categoryIDsByRecipe` maps each
    /// recipe ID to its WP categories (sourced from the local cache).
    /// `recentlyViewedIDs` is the set of recipe IDs the user has opened.
    /// Missing entries in either map mean "unknown" — which we treat as a
    /// MISS for the corresponding filter (a safer default than admitting
    /// every uncategorized result).
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
            if let cookTime {
                guard let seconds = totalSecondsByRecipe[item.id],
                    cookTime.contains(totalSeconds: seconds)
                else {
                    return false
                }
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

/// Discrete cook-time buckets shown as filter chips. Buckets are inclusive
/// of their upper bound so the boundaries don't gap (a recipe at exactly
/// 15 min lands in `.under15`, exactly 30 lands in `.under30`).
public enum CookTimeBucket: String, CaseIterable, Identifiable, Sendable {
    case under15
    case under30
    case under60
    case overHour

    public var id: String { rawValue }

    /// Short label shown in the chip and the action sheet.
    public var label: String {
        switch self {
        case .under15: "≤ 15 min"
        case .under30: "≤ 30 min"
        case .under60: "≤ 60 min"
        case .overHour: "1 hr+"
        }
    }

    /// True when `totalSeconds` (recipe total time in seconds) falls in this
    /// bucket. The three "≤" buckets nest, so `.under30` admits a 15-minute
    /// recipe — the chip is treated as an "at most" cap, not a band.
    public func contains(totalSeconds: Int) -> Bool {
        switch self {
        case .under15: totalSeconds <= 15 * 60
        case .under30: totalSeconds <= 30 * 60
        case .under60: totalSeconds <= 60 * 60
        case .overHour: totalSeconds > 60 * 60
        }
    }
}
