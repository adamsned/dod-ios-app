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
}
