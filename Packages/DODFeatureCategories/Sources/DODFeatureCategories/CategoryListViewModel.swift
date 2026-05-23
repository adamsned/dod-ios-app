import DODDomain
import DODSupport
import Foundation
import Observation

/// List of all WP categories. Loaded once when the tab appears.
/// Spec trace: AC-2.1, AC-2.2, AC-2.4, AC-2.5.
@Observable
@MainActor
public final class CategoryListViewModel {

    public enum LoadState: Equatable {
        case idle, loading, loaded, error
    }

    public private(set) var categories: [DODDomain.Category] = []
    public private(set) var loadState: LoadState = .idle

    private let dependencies: CategoriesDependencies

    public init(dependencies: CategoriesDependencies) {
        self.dependencies = dependencies
    }

    public func onAppear() async {
        guard categories.isEmpty else { return }
        await load()
    }

    public func retry() async {
        await load()
    }

    private func load() async {
        loadState = .loading
        do {
            categories = try await dependencies.fetchCategories()
            loadState = .loaded
        } catch {
            DODLog.network.error("categories load failed: \(String(describing: error))")
            loadState = .error
        }
    }
}
