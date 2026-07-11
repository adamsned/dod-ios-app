import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

/// DUT — a stale `refresh()` must not clobber a newer one.
///
/// `refresh()` can be — and in production routinely is — in flight from more
/// than one caller at once: the Saved tab's `.task` fires on every appear,
/// `.refreshable` drives a pull-to-refresh, `SavedView`'s post-unsave/undo
/// handlers each fire an unstructured `Task { await viewModel.refresh() }`,
/// and the DUT-6 debounced remote-change refresh can land in the middle of
/// any of those. Before the fix, nothing ordered them: whichever fetch
/// RESOLVED LAST won, not whichever STARTED last — so a refresh kicked off
/// before a save landed could resolve AFTER a later refresh had already
/// surfaced that save, silently un-surfacing it again (and, on the same
/// stale pass, reverting `downloadedIDs` / `loadState` too).
///
/// The fix stamps a monotonic `refreshGeneration` at the start of `refresh()`
/// (mirroring `FeedViewModel.loadGeneration` / DUT-511) and re-checks it
/// after every `await` before committing state, so a superseded call's stale
/// response is dropped instead of overwriting the newer one.
///
/// This test drives the race deterministically with `FakeSavedDependencies`'s
/// gate: a `refresh()` call is held mid-fetch (parked before it reads its
/// response) until a second, faster `refresh()` has fully committed, then
/// released with a STALE response captured from before the second refresh's
/// data landed.
@MainActor
@Suite("SavedViewModel refresh vs in-flight refresh (DUT)")
struct SavedViewModelRefreshRaceTests {

    @Test func staleParkedRefreshDoesNotClobberNewerCompletedRefresh() async throws {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.recipes.map(\.id) == [1])

        // Arm a park: the NEXT `savedRecipesWithSavedAt()` call parks mid-fetch
        // and, once released, returns the STALE one-recipe snapshot captured
        // here — modeling a fetch that was already in flight before recipe 2
        // got saved.
        dependencies.armGate = true
        dependencies.gatedResponse = [SavedViewModelTests.makeRecipe(id: 1)]
        let staleRefresh = Task { await viewModel.refresh() }
        await withCheckedContinuation { (reached: CheckedContinuation<Void, Never>) in
            dependencies.gateReached = { reached.resume() }
        }

        // While the stale refresh is parked mid-fetch, recipe 2 gets saved and
        // a SECOND, NEWER refresh runs to completion and surfaces it.
        dependencies.recipes = [
            SavedViewModelTests.makeRecipe(id: 1),
            SavedViewModelTests.makeRecipe(id: 2),
        ]
        await viewModel.refresh()
        #expect(viewModel.recipes.map(\.id) == [1, 2])

        // Release the stale refresh. It resolves with its pre-save snapshot —
        // that must be DROPPED, not committed over the newer, already-correct
        // state.
        dependencies.gate?.resume()
        await staleRefresh.value

        #expect(
            viewModel.recipes.map(\.id) == [1, 2],
            "a stale refresh that started before recipe 2 was saved must not un-surface it after a newer refresh already committed it"
        )
    }
}
