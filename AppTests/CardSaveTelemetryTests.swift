import DODAnalytics
import DODDomain
import DODFeatureRecipeDetail
import DODPersistence
import XCTest

@testable import DODApp

/// DUT-1322 — `TabStack.saveFromCard(item:store:publisher:)` is the shared
/// card long-press save path used by Feed, Search, Saved, and Category
/// Recipes. It performs the same store write as the recipe-detail bookmark
/// tap (`RecipeDetailViewModel.toggleSaved()`) but, until this fix, sent zero
/// telemetry — every save/unsave made by long-pressing a card was invisible
/// to analytics. This suite pins the fix by injecting a recording closure
/// into the new `sendTelemetry` seam rather than mutating the process-wide
/// `Telemetry.shared` singleton (the whole point of the seam).
@MainActor
final class CardSaveTelemetryTests: XCTestCase {

    /// AC: the FIRST save of an item not yet in the store sends exactly one
    /// `.recipeSaved(recipeID:)` carrying the item's id. This is the
    /// Feed/Search/Category long-press-to-save path.
    func test_firstSaveOfUncachedItem_sendsRecipeSaved() async throws {
        let store = try await makeStore()
        let publisher = SavedRecipesWidgetPublisher(store: store, widgetStore: nil)
        let item = makeListItem(id: 42)
        let recorder = EventRecorder()

        let result = await TabStack.saveFromCard(
            item: item,
            store: store,
            publisher: publisher,
            sendTelemetry: { recorder.record($0) }
        )

        XCTAssertTrue(result, "save-from-card must report success on a clean store write")
        XCTAssertEqual(
            recorder.events,
            [.recipeSaved(recipeID: 42)],
            "a first save must emit exactly one recipeSaved event for the saved item's id"
        )
    }

    /// AC: toggling the SAME id a second time (the Saved-tab unsave path,
    /// where a long-press "Remove" flips an already-saved recipe back off)
    /// must send `.recipeUnsaved(recipeID:)`, not another `.recipeSaved`.
    func test_secondToggleOfSameID_sendsRecipeUnsaved() async throws {
        let store = try await makeStore()
        let publisher = SavedRecipesWidgetPublisher(store: store, widgetStore: nil)
        let item = makeListItem(id: 7)
        let recorder = EventRecorder()

        _ = await TabStack.saveFromCard(
            item: item,
            store: store,
            publisher: publisher,
            sendTelemetry: { recorder.record($0) }
        )
        let result = await TabStack.saveFromCard(
            item: item,
            store: store,
            publisher: publisher,
            sendTelemetry: { recorder.record($0) }
        )

        XCTAssertTrue(result, "the unsave toggle must also report success on a clean store write")
        XCTAssertEqual(
            recorder.events,
            [.recipeSaved(recipeID: 7), .recipeUnsaved(recipeID: 7)],
            "the second toggle of the same id must emit recipeUnsaved (Saved-tab unsave), "
                + "not recipeSaved again"
        )
    }

    /// AC: the emitted event's recipe id always matches the saved item's id,
    /// not some other identifier (e.g. a stale/default id).
    func test_eventRecipeID_matchesSavedItemID() async throws {
        let store = try await makeStore()
        let publisher = SavedRecipesWidgetPublisher(store: store, widgetStore: nil)
        let item = makeListItem(id: 999)
        let recorder = EventRecorder()

        _ = await TabStack.saveFromCard(
            item: item,
            store: store,
            publisher: publisher,
            sendTelemetry: { recorder.record($0) }
        )

        guard case .recipeSaved(let recipeID) = recorder.events.first else {
            XCTFail("expected a recipeSaved event, got \(String(describing: recorder.events.first))")
            return
        }
        XCTAssertEqual(recipeID, 999)
    }

    /// AC: exactly one event per successful call, never two (e.g. no
    /// accidental double-send from both the cache step and the toggle step).
    func test_eachSuccessfulCall_sendsExactlyOneEvent() async throws {
        let store = try await makeStore()
        let publisher = SavedRecipesWidgetPublisher(store: store, widgetStore: nil)
        let item = makeListItem(id: 1)
        let recorder = EventRecorder()

        _ = await TabStack.saveFromCard(
            item: item,
            store: store,
            publisher: publisher,
            sendTelemetry: { recorder.record($0) }
        )
        XCTAssertEqual(recorder.events.count, 1, "a single save call must send exactly one event")

        _ = await TabStack.saveFromCard(
            item: item,
            store: store,
            publisher: publisher,
            sendTelemetry: { recorder.record($0) }
        )
        XCTAssertEqual(
            recorder.events.count,
            2,
            "a second toggle call must send exactly one more event"
        )
    }
}

// MARK: - Helpers

extension CardSaveTelemetryTests {

    fileprivate func makeStore() async throws -> RecipeStore {
        let container = try RecipeStore.inMemoryContainer()
        return RecipeStore(modelContainer: container)
    }

    fileprivate func makeListItem(id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Test Recipe \(id)",
            excerpt: "An excerpt.",
            heroImage: URL(string: "https://example.com/\(id).jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(id))
        )
    }
}

/// Thread-safe event sink for the `sendTelemetry` test seam. `saveFromCard`
/// takes a `@Sendable` closure, so a bare captured `var` would trigger a
/// Swift 6 concurrency warning on mutation across the boundary; a lock-backed
/// recorder (mirroring `DODAnalytics.RecordingTelemetryTransport`) avoids
/// that without silencing anything.
private final class EventRecorder: @unchecked Sendable {

    private let lock = NSLock()
    private var _events: [AnalyticsEvent] = []

    var events: [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    func record(_ event: AnalyticsEvent) {
        lock.lock()
        defer { lock.unlock() }
        _events.append(event)
    }
}
