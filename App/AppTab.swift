/// Top-level tab identifier.
enum AppTab: Hashable, CaseIterable, Identifiable {
    case feed
    case categories
    case search
    case saved

    var id: Self { self }

    var title: String {
        switch self {
        case .feed: "Recipes"
        case .categories: "Categories"
        case .search: "Search"
        case .saved: "Saved"
        }
    }

    var systemImage: String {
        switch self {
        case .feed: "house"
        case .categories: "square.grid.2x2"
        case .search: "magnifyingglass"
        case .saved: "heart"
        }
    }

    var telemetryName: String {
        switch self {
        case .feed: "feed"
        case .categories: "categories"
        case .search: "search"
        case .saved: "saved"
        }
    }
}
