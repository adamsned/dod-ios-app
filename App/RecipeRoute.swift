import DODDomain
import Foundation

/// Type-safe navigation routes pushed onto a tab's NavigationStack.
enum RecipeRoute: Hashable {
    /// `autoStartCookMode` is set by the StartCookModeIntent deep link
    /// (US-10) so the destination view presents Cook Mode on first appear
    /// without an extra user tap. Defaulted to `false` for the normal
    /// list-tap path.
    case recipe(item: RecipeListItem, autoStartCookMode: Bool = false)
    case category(DODDomain.Category)
    /// v2 Search overhaul (1/3) — the Search screen, PUSHED within the Feed
    /// tab's navigation stack (Search is no longer a tab). The Feed header's
    /// magnifying-glass button appends this route; ``TabStack`` renders
    /// ``DODFeatureSearch/SearchView`` for it. Carries no payload — there's a
    /// single search screen — so its identity is the case itself.
    case search

    // DUT-617 — identity is keyed on the recipe **id** (+ `autoStartCookMode`)
    // and the category, NOT the whole associated `RecipeListItem`. The
    // synthesized `Hashable` compared every field of the list item, so the same
    // recipe id arriving from two entry points (e.g. a fresh list fetch vs a
    // deep-link resolve) produced a different-looking `RecipeListItem` payload
    // and failed `==` — breaking NavigationStack de-duplication for what is
    // logically the same destination. The payload is preserved (views still
    // read the full item); only equality/hashing is narrowed.
    static func == (lhs: RecipeRoute, rhs: RecipeRoute) -> Bool {
        switch (lhs, rhs) {
        case (.recipe(let lItem, let lAuto), .recipe(let rItem, let rAuto)):
            return lItem.id == rItem.id && lAuto == rAuto
        case (.category(let lCategory), .category(let rCategory)):
            // DUT-658 — key category identity on `id` only, mirroring the
            // `.recipe` narrowing above. The whole `Category` includes a volatile
            // `count` (recipe tally) that differs between a browse-list fetch and
            // a deep-link resolve for the SAME category, which broke NavigationStack
            // de-duplication (two logically-identical destinations failed `==`).
            return lCategory.id == rCategory.id
        case (.search, .search):
            // Single search screen — always the same destination, so two
            // `.search` routes de-dupe (NavigationStack won't double-push).
            return true
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .recipe(let item, let autoStartCookMode):
            hasher.combine(0)
            hasher.combine(item.id)
            hasher.combine(autoStartCookMode)
        case .category(let category):
            hasher.combine(1)
            // DUT-658 — hash on `id` only so it stays consistent with the
            // narrowed `==` above (a differing `count` must not change the hash).
            hasher.combine(category.id)
        case .search:
            hasher.combine(2)
        }
    }
}
