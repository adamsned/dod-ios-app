import DODDomain
import Foundation

/// Type-safe navigation routes pushed onto a tab's NavigationStack.
enum RecipeRoute: Hashable {
    case recipe(item: RecipeListItem)
    case category(DODDomain.Category)
}
