import DODDomain
import Foundation
import Observation

public protocol BrowseAxesProviding: Sendable {
    func loadAxes() async throws -> BrowseAxesConfig
}

@Observable
@MainActor
public final class BrowseByViewModel {
    public enum LoadState: Equatable { case idle, loading, loaded, error }

    public private(set) var axes: [BrowseAxis] = []
    public private(set) var loadState: LoadState = .idle

    private let provider: BrowseAxesProviding
    private let dependencies: CategoriesDependencies

    public init(provider: BrowseAxesProviding, dependencies: CategoriesDependencies) {
        self.provider = provider
        self.dependencies = dependencies
    }

    /// A value is kept when a 1-item probe of its tags returns items; a failed probe keeps it
    /// (fail open) so a flaky network never hides content.
    nonisolated static func pruneEmpty(
        _ axes: [BrowseAxis],
        dependencies: CategoriesDependencies
    ) async -> [BrowseAxis] {
        var result: [BrowseAxis] = []
        for axis in axes {
            var kept: [BrowseAxisValue] = []
            for value in axis.values {
                // If fetchPosts succeeds and returns items, keep the value
                // If fetchPosts fails (network error), keep the value (fail open)
                do {
                    let page = try await dependencies.fetchPosts(tagIDs: value.tagIDs, page: 1)
                    if !page.items.isEmpty {
                        kept.append(value)
                    }
                } catch {
                    // Fail open - keep the value if there's a network error
                    kept.append(value)
                }
            }
            if !kept.isEmpty { result.append(BrowseAxis(slug: axis.slug, title: axis.title, values: kept)) }
        }
        return result
    }
}
