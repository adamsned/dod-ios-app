import DODDomain
import Foundation
import Testing

@testable import DODFeatureFeed

// DUT-534 Part 2 — the Feed card "Add to Shopping List" quick-add flow: a
// `RecipeListItem` → minimal `Recipe` → appender append, mapped onto the
// confirmation snackbar. Uses `FakeFeedDependencies` (see `FeedViewModelTests`).

@MainActor
@Suite("FeedViewModel Add to Shopping List (DUT-534 Part 2)")
struct FeedViewModelShoppingListTests {

    private static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "Excerpt \(id)",
            heroImage: URL(string: "https://example.com/\(id).jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/recipe-\(id)/")
        )
    }

    @Test("Success maps to the added snackbar + View action")
    func successShowsAddedSnackbar() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .added(count: 3)
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.addToShoppingList(Self.makeItem(42))

        #expect(viewModel.shoppingListSnackbarMessage == "Added 3 ingredients to your Shopping List")
        #expect(viewModel.shoppingListSnackbarActionTitle == "View")
        // The card's identity flowed through as a minimal, ingredient-empty
        // recipe (the appender hydrates ingredients itself).
        #expect(dependencies.appendedRecipes.count == 1)
        #expect(dependencies.appendedRecipes.first?.id == 42)
        #expect(dependencies.appendedRecipes.first?.ingredients.isEmpty == true)
    }

    @Test("Singular ingredient copy is grammatical")
    func singularCopy() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .added(count: 1)
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.addToShoppingList(Self.makeItem(1))

        #expect(viewModel.shoppingListSnackbarMessage == "Added 1 ingredient to your Shopping List")
    }

    @Test("couldntLoad maps to the fallback copy with no action")
    func couldntLoadShowsFallback() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .couldntLoad
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.addToShoppingList(Self.makeItem(7))

        #expect(
            viewModel.shoppingListSnackbarMessage
                == "Couldn't load ingredients — open the recipe to add."
        )
        #expect(viewModel.shoppingListSnackbarActionTitle == nil)
    }

    @Test("Dismiss clears both the message and the action")
    func dismissClearsSnackbar() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .added(count: 2)
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.addToShoppingList(Self.makeItem(9))
        viewModel.dismissShoppingListSnackbar()

        #expect(viewModel.shoppingListSnackbarMessage == nil)
        #expect(viewModel.shoppingListSnackbarActionTitle == nil)
    }

    // DUT-541 — a rapid double long-press fires two independent add Tasks for the
    // same card. The in-flight guard must drop the second concurrent add so the
    // additive appender (CL-77) runs exactly ONCE; a deliberate re-add AFTER the
    // first completes must still stack.

    @Test("Two concurrent adds of the same id append only once (in-flight guard)")
    func concurrentDoubleAddAppendsOnce() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .added(count: 3)
        // Hold the first append in flight until the test releases it, so the
        // second Task is guaranteed to observe the id still in `addingIDs`.
        let gate = AsyncGate()
        dependencies.appendGate = { await gate.wait() }
        let viewModel = FeedViewModel(dependencies: dependencies)
        let item = Self.makeItem(42)

        async let first: Void = viewModel.addToShoppingList(item)
        // Let `first` reach the gate (it has already inserted id 42 + recorded
        // its append) before the second add races in.
        await gate.waitUntilWaiting()
        await viewModel.addToShoppingList(item)  // guard drops this one immediately
        await gate.open()
        await first

        #expect(dependencies.appendedRecipes.count == 1)
        #expect(dependencies.appendedRecipes.first?.id == 42)
    }

    @Test("A sequential re-add after completion still appends again (CL-77)")
    func sequentialReAddStacks() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .added(count: 3)
        let viewModel = FeedViewModel(dependencies: dependencies)
        let item = Self.makeItem(42)

        await viewModel.addToShoppingList(item)
        await viewModel.addToShoppingList(item)  // first fully completed → allowed

        #expect(dependencies.appendedRecipes.count == 2)
    }

    @Test("Concurrent adds of DIFFERENT ids each append (guard is per-item)")
    func concurrentDifferentIDsBothAppend() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shoppingListResult = .added(count: 3)
        let gate = AsyncGate()
        dependencies.appendGate = { await gate.wait() }
        let viewModel = FeedViewModel(dependencies: dependencies)

        async let first: Void = viewModel.addToShoppingList(Self.makeItem(1))
        async let second: Void = viewModel.addToShoppingList(Self.makeItem(2))
        // Both adds are for distinct ids, so neither is guarded out; let them
        // both park on the gate, then release.
        await gate.waitUntilWaiting(count: 2)
        await gate.open()
        _ = await (first, second)

        #expect(dependencies.appendedRecipes.count == 2)
        #expect(Set(dependencies.appendedRecipes.map(\.id)) == [1, 2])
    }
}

/// DUT-541 test helper — a one-shot gate a fake appender parks on, so a test can
/// hold N appends in flight and prove the view model's in-flight guard behavior.
/// `wait()` suspends callers until `open()`; `waitUntilWaiting()` lets the test
/// deterministically observe that the expected number of callers have parked
/// before it races the next add in.
actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var waiterCount = 0
    private var arrivalWaiters: [(target: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func wait() async {
        if isOpen { return }
        waiterCount += 1
        resolveArrivals()
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for continuation in pending { continuation.resume() }
    }

    /// Suspend until at least `count` callers have entered `wait()`.
    func waitUntilWaiting(count: Int = 1) async {
        if waiterCount >= count { return }
        await withCheckedContinuation { continuation in
            arrivalWaiters.append((target: count, continuation: continuation))
        }
    }

    private func resolveArrivals() {
        let ready = arrivalWaiters.filter { waiterCount >= $0.target }
        arrivalWaiters.removeAll { waiterCount >= $0.target }
        for entry in ready { entry.continuation.resume() }
    }
}
