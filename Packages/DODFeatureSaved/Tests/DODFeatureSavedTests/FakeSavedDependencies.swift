import DODDomain
import Foundation

@testable import DODFeatureSaved

/// Shared `SavedDependencies` test double, used across `SavedViewModelTests`,
/// `SavedViewModelRefreshRaceTests`, `SavedViewModelDownloadWarningTests`, and
/// `SavedViewSnapshotTests`. Extracted to its own file (mirroring
/// `FakeSearchDependencies.swift` / `FakeRecipeDetailDependencies.swift`) so no
/// single test file needs to carry it under SwiftLint's `file_length` cap.
final class FakeSavedDependencies: SavedDependencies, @unchecked Sendable {
    var recipes: [Recipe] = []
    /// DUT-513 — per-id synced `savedAt`, driving ``savedRecipesWithSavedAt()``.
    /// A test simulates a re-save by stamping an id's save time newer than the
    /// unsave, then asserts the card reappears without a manual clear. Ids absent
    /// here surface with `.distantPast` (never read as a fresh re-save).
    var savedAtByID: [Int: Date] = [:]
    var shouldFail = false
    /// Test-only flag to make ``downloadedRecipeIDs()`` throw (best-effort test).
    /// T-774 / DUT-80 — verifies that a failed download-id fetch doesn't crash
    /// the refresh, just falls back to no badges.
    var shouldFailDownloadedIDs = false
    /// T-774 / DUT-80 — the set ``downloadedRecipeIDs()`` returns, so a test can
    /// assert the view model hydrates `downloadedIDs` for the Saved-tab badge.
    var downloadedIDs: Set<Int> = []
    /// T-775 / DUT-81 — recipe ids the view model asked to un-download, so a
    /// test can assert the store write routed through the dependency.
    var removedDownloadIDs: [Int] = []
    /// T-778 / DUT-84 — drives ``isOnline()`` so a test can exercise the offline
    /// remove-download warning. Defaults online (no warning).
    var online = true
    /// Number of times ``savedRecipes()`` has been called — lets a test assert
    /// the view model coalesces a remote-change burst into a single re-fetch.
    private(set) var savedRecipesCallCount = 0

    /// Test-only park for a refresh-race test (DUT): when `true`, the NEXT
    /// ``savedRecipesWithSavedAt()`` call parks on ``gate`` until a test
    /// resumes it, then returns ``gatedResponse`` (captured at arm time)
    /// instead of the live ``recipes`` — modeling a fetch whose result
    /// reflects state from BEFORE a later, faster refresh overtook it.
    /// One-shot: cleared as soon as a call consumes it.
    var armGate = false
    /// The stale snapshot the parked call returns once released. `nil` falls
    /// back to the live `recipes` at resume time.
    var gatedResponse: [Recipe]?
    /// The parked call's continuation, so a test can release it explicitly.
    var gate: CheckedContinuation<Void, Never>?
    /// Fires the instant the parked call actually reaches the gate, so a test
    /// can await a signal that a concurrent refresh is genuinely in flight
    /// before racing a second one (avoids sleep-based timing guesses).
    var gateReached: (@Sendable () -> Void)?

    /// Synthetic remote-change trigger (DUT-6). The view model subscribes to
    /// ``remoteChanges()``; a test calls ``fireRemoteChange()`` to simulate a
    /// CloudKit import landing, then asserts the view model re-fetched.
    private let remoteChangeStream: AsyncStream<Void>
    private let remoteChangeContinuation: AsyncStream<Void>.Continuation
    /// Number of times ``remoteChanges()`` has been called — lets the DUT-481
    /// leak test confirm the observing task actually started before release.
    private(set) var remoteChangesCallCount = 0

    /// DUT-365 — test hook to track calls to publishSavedWidget() and allow tests
    /// to inject custom behavior. Defaults to a no-op; tests can assign a closure
    /// that increments a counter or performs other verification.
    var publishSavedWidgetImpl: (() async -> Void) = {}

    init() {
        (remoteChangeStream, remoteChangeContinuation) = AsyncStream.makeStream()
    }

    func savedRecipes() async throws -> [Recipe] {
        savedRecipesCallCount += 1
        if shouldFail { throw URLError(.unknown) }
        return recipes
    }

    func savedRecipesWithSavedAt() async throws -> [(recipe: Recipe, savedAt: Date)] {
        savedRecipesCallCount += 1
        if shouldFail { throw URLError(.unknown) }
        if armGate {
            armGate = false
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                gate = continuation
                gateReached?()
            }
            let stale = gatedResponse ?? recipes
            return stale.map { ($0, savedAtByID[$0.id] ?? .distantPast) }
        }
        return recipes.map { ($0, savedAtByID[$0.id] ?? .distantPast) }
    }

    func downloadedRecipeIDs() async throws -> Set<Int> {
        if shouldFailDownloadedIDs { throw URLError(.unknown) }
        return downloadedIDs
    }

    func publishSavedWidget() async {
        await publishSavedWidgetImpl()
    }

    func removeDownload(id: Int) async throws {
        removedDownloadIDs.append(id)
        downloadedIDs.remove(id)
    }

    func isOnline() async -> Bool { online }

    func remoteChanges() -> AsyncStream<Void> {
        remoteChangesCallCount += 1
        return remoteChangeStream
    }

    /// Simulate one CloudKit remote-import signal reaching the view model.
    func fireRemoteChange() {
        remoteChangeContinuation.yield(())
    }
}
