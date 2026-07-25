import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// A rapid double-tap on the visible "Retry" button (shown only in
/// `.retryableError`) has no built-in reentrancy protection: `retryLoad()`
/// unconditionally kicks off a full `fetchAndParse()` pipeline (network HTML
/// fetch → off-main JSON-LD classify/parse → `apply(classification:)`, which
/// mutates `loadState`/`recipe`/`blurbBlocks` and fires `loadRelated`). Two
/// overlapping taps therefore raced two independent pipelines, wasting a
/// duplicate network call at minimum and risking UI flicker / an
/// inconsistent intermediate state at worst — whichever call happened to
/// resolve last would win.
///
/// Same race class, same fix shape as `CategoryRecipesViewModel.isLoadInFlight`
/// (DUT-706) and `FeedViewModel.loadGeneration` (DUT-511): a synchronous
/// in-flight guard set before the first `await` and cleared via `defer`, so
/// a second call arriving while the first is still running is a no-op
/// instead of a second concurrent pipeline.
@MainActor
@Suite("RecipeDetailViewModel retryLoad() double-tap reentrancy")
struct RecipeDetailRetryReentrancyTests {

    @Test func overlappingRetryCallsFetchHTMLOnlyOnce() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 701, withDetail: true)

        let resumeFetch = AsyncStream<Void>.makeStream()
        dependencies.fetchHTMLGate = {
            for await _ in resumeFetch.stream { return }
        }

        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 701
        )

        // First tap: starts `retryLoad()`, which parks inside `fetchHTML`
        // on the gate before it can return.
        let firstRetry = Task { await viewModel.retryLoad() }

        // Spin until the first call has genuinely reached (and parked on)
        // the gate before racing the second tap against it.
        var attempts = 0
        while dependencies.fetchCount == 0, attempts < 500 {
            try await Task.sleep(nanoseconds: 1_000_000)  // 1 ms
            attempts += 1
        }
        #expect(dependencies.fetchCount == 1)

        // Second tap: a rapid double-tap while the first call is still
        // in flight. Run it as its own `Task` (not an inline `await`) —
        // if the guard is missing, this call proceeds all the way into
        // `fetchHTML` and parks on the SAME gate as the first call, and an
        // inline `await` here would deadlock this test (nothing left to
        // release the gate). Driving it as a `Task` lets a still-buggy
        // implementation show up as an extra `fetchCount` increment
        // instead of a hang.
        let secondRetry = Task { await viewModel.retryLoad() }

        // `fetchCount` increments synchronously at the top of `fetchHTML`,
        // before it ever awaits the gate — so a brief, bounded wait is
        // enough to observe whether the second call reached `fetchHTML`
        // at all, whether or not the guard exists.
        try await Task.sleep(nanoseconds: 50_000_000)  // 50 ms
        #expect(
            dependencies.fetchCount == 1,
            "a double-tap while the first retry is in flight must not start a second fetch"
        )

        // Release every in-flight fetch — there may be more than one if
        // the guard is missing — and let both calls finish.
        resumeFetch.continuation.yield(())
        resumeFetch.continuation.yield(())
        resumeFetch.continuation.finish()
        await firstRetry.value
        await secondRetry.value

        // Still only ever fetched once, total.
        #expect(dependencies.fetchCount == 1)
    }

    @Test func guardResetsAfterCompletionSoALaterSequentialRetryProceeds() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 702, withDetail: true)

        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 702
        )

        // First retry: no gating, runs to completion synchronously.
        await viewModel.retryLoad()
        #expect(dependencies.fetchCount == 1)

        // A later, fully sequential (non-overlapping) retry must NOT be
        // permanently locked out by a stale in-flight flag — the guard has
        // to clear once the first call actually finishes.
        await viewModel.retryLoad()
        #expect(
            dependencies.fetchCount == 2,
            "the guard must reset after completion so a later retry can still proceed"
        )
    }

    @Test func endStateAfterOverlappingRetriesMatchesANormalSingleRetry() async throws {
        // Control: a single, ungated, un-raced retry — the expected
        // "healthy" end state.
        let controlDependencies = FakeRecipeDetailDependencies()
        controlDependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 703, withDetail: true)
        let controlViewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: controlDependencies,
            listItemID: 703
        )
        await controlViewModel.retryLoad()

        #expect(controlViewModel.loadState == .ready)
        #expect(controlViewModel.recipe?.id == 703)

        // Experiment: the same recipe, but the retry is double-tapped
        // (overlapping calls) partway through the fetch.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 703, withDetail: true)

        let resumeFetch = AsyncStream<Void>.makeStream()
        dependencies.fetchHTMLGate = {
            for await _ in resumeFetch.stream { return }
        }

        let viewModel = RecipeDetailViewModelTests.makeViewModel(
            dependencies: dependencies,
            listItemID: 703
        )

        let firstRetry = Task { await viewModel.retryLoad() }

        var attempts = 0
        while dependencies.fetchCount == 0, attempts < 500 {
            try await Task.sleep(nanoseconds: 1_000_000)  // 1 ms
            attempts += 1
        }
        #expect(dependencies.fetchCount == 1)

        // The double-tap: a no-op given the guard. Driven as its own
        // `Task` (see `overlappingRetryCallsFetchHTMLOnlyOnce` for why an
        // inline `await` here would deadlock a still-buggy implementation).
        let secondRetry = Task { await viewModel.retryLoad() }
        try await Task.sleep(nanoseconds: 50_000_000)  // 50 ms

        resumeFetch.continuation.yield(())
        resumeFetch.continuation.yield(())
        resumeFetch.continuation.finish()
        await firstRetry.value
        await secondRetry.value

        // The double-tap must not have left the view model in a broken
        // intermediate state — the end state matches the healthy control.
        #expect(viewModel.loadState == controlViewModel.loadState)
        #expect(viewModel.recipe?.id == controlViewModel.recipe?.id)
        #expect(viewModel.loadState == .ready)
        #expect(viewModel.recipe?.id == 703)
        // The "healthy end state" contract includes not having wasted a
        // second network round trip — both calls resolving to the same
        // recipe would otherwise mask a missing guard (both concurrent
        // fetches merge identical data), so this must be asserted
        // explicitly rather than inferred from `loadState`/`recipe` alone.
        #expect(
            dependencies.fetchCount == 1,
            "the double-tap must not have triggered a second fetch, even though the end state would look identical either way"
        )
    }
}
