import Observation
import SwiftUI

/// Per-tab `NavigationPath` storage. Lives in `RootView`'s @State so tab
/// switches preserve in-tab navigation history.
@Observable
final class NavigationPaths {

    private var feed: [RecipeRoute] = []
    private var categories: [RecipeRoute] = []
    private var search: [RecipeRoute] = []
    private var saved: [RecipeRoute] = []

    func binding(for tab: AppTab) -> Binding<[RecipeRoute]> {
        switch tab {
        case .feed:
            Binding(get: { self.feed }, set: { self.feed = $0 })
        case .categories:
            Binding(get: { self.categories }, set: { self.categories = $0 })
        case .search:
            Binding(get: { self.search }, set: { self.search = $0 })
        case .saved:
            Binding(get: { self.saved }, set: { self.saved = $0 })
        }
    }

    func append(_ route: RecipeRoute, to tab: AppTab) {
        switch tab {
        case .feed: feed.append(route)
        case .categories: categories.append(route)
        case .search: search.append(route)
        case .saved: saved.append(route)
        }
    }
}
