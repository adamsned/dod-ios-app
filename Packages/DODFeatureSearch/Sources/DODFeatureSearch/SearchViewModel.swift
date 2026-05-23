import DODDomain
import DODSupport
import Foundation
import Observation

/// Debounced search view model.
///
/// Spec trace: AC-3.1 (300ms debounce), AC-3.4 (empty state),
/// AC-3.6 (hashed query telemetry), AC-3.7 (offline).
@Observable
@MainActor
public final class SearchViewModel {

    public enum State: Equatable {
        case idle
        case searching
        case results
        case noResults
        case offline
    }

    public var query: String = "" {
        didSet { scheduleSearch() }
    }

    public private(set) var state: State = .idle
    public private(set) var items: [RecipeListItem] = []

    private let dependencies: SearchDependencies
    /// Public for tests to control timing without sleeping for real.
    public var debounceMilliseconds: Int = 300
    private var debounceTask: Task<Void, Never>?

    public init(dependencies: SearchDependencies) {
        self.dependencies = dependencies
    }

    public func clear() {
        query = ""
        items = []
        state = .idle
    }

    /// For tests: bypass the debounce.
    public func runImmediateSearch() async {
        debounceTask?.cancel()
        await performSearch()
    }

    private func scheduleSearch() {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            items = []
            state = .idle
            return
        }
        debounceTask = Task { [weak self] in
            guard let self else { return }
            let delay = await self.debounceMilliseconds
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            if Task.isCancelled { return }
            await self.performSearch()
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }

        // Connectivity check before swallowing the network call.
        if await !dependencies.isOnline() {
            state = .offline
            items = []
            return
        }

        state = .searching
        do {
            let fetched = try await dependencies.search(query: trimmed)
            try await dependencies.cache(listItems: fetched)
            items = fetched
            state = fetched.isEmpty ? .noResults : .results
            // AC-3.6: telemetry sends ONLY the hash, never the raw query.
            let hash = StringHasher.sha256Hex(trimmed)
            await dependencies.sendSearchTelemetry(queryHash: hash)
        } catch {
            DODLog.network.error("search failed: \(String(describing: error))")
            state = await dependencies.isOnline() ? .noResults : .offline
        }
    }
}
