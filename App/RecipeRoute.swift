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
            return lCategory == rCategory
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
            hasher.combine(category)
        }
    }
}
