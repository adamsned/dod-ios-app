import Foundation

/// v2 Search overhaul (3/3) — the curated "Try Searching" chip pool.
///
/// Wave 3 replaces the SOURCE of the idle "Try" pills. Waves 1/2 drew the
/// pills from the top-30 WP *categories* (browse topics); Wave 3 swaps in a
/// hand-curated pool of 100 specific *search terms* — dishes, proteins,
/// ingredients, techniques, cuisines. Every term in ``pool`` was
/// pre-validated to return results on the live `?search=` endpoint, so a
/// tapped chip always lands on a populated result set. The terms are stored
/// as the **raw lowercase query strings** (WP search is case-insensitive);
/// the pill LABEL is Title-Cased for display via ``displayName(for:)`` while
/// the SEARCH QUERY stays the raw term.
///
/// Distinct from the "Categories" browse list below the chips
/// (`browseCategories`, unchanged): a chip runs a text search for the term,
/// a category row opens a broad topic's recipe list. "Latest Recipes" is NOT
/// one of the 100 — it is the pinned, special what's-new affordance
/// (``SearchTryChips/latestRecipes``) that runs the recent-posts fetch.
public enum SearchTryChips {

    /// The 100 curated, pre-validated search terms, stored as raw lowercase
    /// queries. Order here is the canonical order; the rendered slate is a
    /// per-cold-launch shuffle over this pool (see
    /// `SearchViewModel.pickTrySlate(...)`). Do NOT add/remove/substitute
    /// without re-validating that each term returns results on the live
    /// `?search=` endpoint.
    public static let pool: [String] = [
        "lasagna", "chili", "pot roast", "chicken pot pie", "chicken parmesan",
        "fajitas", "tacos", "enchiladas", "cheesesteak", "meatloaf",
        "beef stew", "chicken and dumplings", "pulled pork", "brisket", "chicken wings",
        "stir fry", "curry", "mac and cheese", "shepherd's pie", "frittata",
        "pizza", "deep dish pizza", "pancakes", "french toast", "hash browns",
        "breakfast casserole", "biscuits and gravy", "dutch baby", "cinnamon rolls", "monkey bread",
        "cornbread", "biscuits", "garlic bread", "dinner rolls", "no knead bread",
        "sourdough", "artisan bread", "banana bread", "peach cobbler", "berry cobbler",
        "blackberry cobbler", "apple crisp", "peach crisp", "dump cake", "skillet cookie",
        "skillet brownie", "brownies", "chocolate cake", "pound cake", "dutch apple pie",
        "cinnamon apples", "ground beef", "chicken thighs", "pork belly", "chuck roast",
        "bacon", "sausage", "steak", "ribeye", "salmon",
        "shrimp", "buttermilk", "brown sugar", "cream cheese", "jalapeno",
        "sweet potato", "black beans", "mushrooms", "spinach", "honey",
        "bourbon", "pumpkin", "blueberry", "cherry", "lemon",
        "corn", "scalloped potatoes", "mashed potatoes", "roasted vegetables", "brussels sprouts",
        "green bean casserole", "jalapeno poppers", "queso", "guacamole", "salsa",
        "campfire", "one pot", "skillet", "weeknight", "30 minute",
        "comfort food", "game day", "crispy", "mexican", "italian",
        "cajun", "southern", "tex mex", "thai", "greek",
    ]

    /// The pinned what's-new chip. Not one of the 100 — it keeps its special
    /// latest-posts behavior (`surfaceLatestRecipes()`), so its `query` is
    /// empty and it is flagged `isLatestRecipes`.
    public static let latestRecipes = SearchTryChip(
        query: "",
        display: "Latest Recipes",
        isLatestRecipes: true
    )

    /// Build a chip for a raw pool term, deriving the Title-Cased display
    /// label while keeping `query` as the raw lowercase term.
    public static func chip(for raw: String) -> SearchTryChip {
        SearchTryChip(query: raw, display: displayName(for: raw), isLatestRecipes: false)
    }

    /// Title-Case a raw term for the pill label, following the app's Title
    /// Case rule (CL-305): capitalize each word except small words that are
    /// neither first nor last. Special-cased entries win outright:
    /// "tex mex" → "Tex-Mex" (hyphen the compound; the query stays "tex mex")
    /// and "30 minute" → "30 Minute". No em dashes in copy (feedback rule).
    public static func displayName(for raw: String) -> String {
        if let special = specialDisplayNames[raw] { return special }
        let words = raw.split(separator: " ", omittingEmptySubsequences: true)
        guard !words.isEmpty else { return raw }
        let lastIndex = words.count - 1
        return words.enumerated()
            .map { index, word -> String in
                let text = String(word)
                if index != 0, index != lastIndex, smallWords.contains(text) {
                    return text
                }
                return text.prefix(1).uppercased() + text.dropFirst()
            }
            .joined(separator: " ")
    }

    /// Display overrides where a plain Title-Case pass is wrong. "tex mex"
    /// reads as a hyphenated cuisine; "30 minute" is pinned explicitly per
    /// spec. The KEYS are raw pool terms; the search query is unaffected.
    static let specialDisplayNames: [String: String] = [
        "tex mex": "Tex-Mex",
        "30 minute": "30 Minute",
    ]

    /// Words kept lowercase in Title Case when they fall between the first
    /// and last word (CL-305). Only "and" appears in the current pool, but
    /// the full set keeps the mapper correct if the pool grows.
    static let smallWords: Set<String> = [
        "a", "an", "and", "as", "at", "but", "by", "for", "from", "in",
        "into", "nor", "of", "on", "onto", "or", "per", "the", "to", "up",
        "via", "vs", "with",
    ]
}

/// One "Try Searching" chip. A pool chip carries the raw lowercase `query`
/// run against WP `?search=` when tapped, plus its Title-Cased `display`
/// label. The pinned ``SearchTryChips/latestRecipes`` chip sets
/// `isLatestRecipes` and an empty `query` (it runs the recent-posts fetch
/// instead of a text search).
public struct SearchTryChip: Identifiable, Equatable, Sendable {
    /// Raw lowercase query for the text search. Empty for Latest Recipes.
    public let query: String
    /// Title-Cased pill label.
    public let display: String
    /// True only for the pinned Latest Recipes chip.
    public let isLatestRecipes: Bool

    public init(query: String, display: String, isLatestRecipes: Bool) {
        self.query = query
        self.display = display
        self.isLatestRecipes = isLatestRecipes
    }

    /// Stable identity: the raw query uniquely keys a pool chip (all 100 are
    /// unique); the pinned chip uses a fixed sentinel so it never collides
    /// with the empty-query default.
    public var id: String { isLatestRecipes ? "dod.search.tryChip.latestRecipes" : query }
}
