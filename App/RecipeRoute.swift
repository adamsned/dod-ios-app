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
}
