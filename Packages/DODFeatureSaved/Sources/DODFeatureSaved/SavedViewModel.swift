import DODDomain
import DODSupport
import Foundation
import Observation

/// Spec trace: AC-5.3 (saved list), AC-5.8 (empty state).
@Observable
@MainActor
public final class SavedViewModel {

    public enum LoadState: Equatable {
        case idle, loading, loaded, empty, error
    }

    public private(set) var recipes: [Recipe] = []
    public private(set) var loadState: LoadState = .idle

    private let dependencies: SavedDependencies

    public init(dependencies: SavedDependencies) {
        self.dependencies = dependencies
    }

    /// Re-runs every time the view appears so changes from the detail screen
    /// surface immediately.
    public func refresh() async {
        loadState = .loading
        do {
            recipes = try await dependencies.savedRecipes()
            loadState = recipes.isEmpty ? .empty : .loaded
        } catch {
            DODLog.persistence.error("saved load failed: \(String(describing: error))")
            loadState = .error
        }
    }
}
