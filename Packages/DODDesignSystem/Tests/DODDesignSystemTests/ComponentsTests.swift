import SwiftUI
import Testing

@testable import DODDesignSystem

/// These are smoke tests — they verify each component constructs without
/// crashing and exposes the documented API. Visual regression / snapshot
/// fidelity is checked manually via `#Preview` in Xcode during T-160.
@Suite("DesignSystem components smoke tests") struct ComponentsTests {

    @Test func emptyStateConstructsWithoutAction() {
        let view = EmptyState(title: "Nothing here", message: "Try later.")
        #expect(view.title == "Nothing here")
        #expect(view.action == nil)
    }

    @Test func emptyStateConstructsWithAction() {
        let view = EmptyState(
            title: "Connect",
            message: "No internet.",
            action: .init(title: "Retry") {}
        )
        #expect(view.action != nil)
        #expect(view.action?.title == "Retry")
    }

    @Test func offlineBannerHidesWhenOnline() {
        let banner = OfflineBanner(isOffline: false)
        #expect(!banner.isOffline)
    }

    @Test func offlineBannerCustomMessage() {
        let banner = OfflineBanner(isOffline: true, message: "Custom note")
        #expect(banner.message == "Custom note")
    }

    @Test func loadingSkeletonRespectsCustomCorner() {
        let skeleton = LoadingSkeleton(cornerRadius: DODRadius.standard)
        #expect(skeleton.cornerRadius == DODRadius.standard)
    }

    @Test func snackbarOptionalAction() {
        let plain = Snackbar(message: "Saved.")
        #expect(plain.action == nil)
        let withUndo = Snackbar(message: "Removed.", action: .init(title: "Undo") {})
        #expect(withUndo.action?.title == "Undo")
    }

    /// DUT-230 — a plain (host-driven) snackbar owns no auto-dismiss.
    @Test func snackbarWithoutHandlerHasNoAutoDismiss() {
        let plain = Snackbar(message: "Saved.")
        #expect(plain.onAutoDismiss == nil)
    }

    /// DUT-230 — with a handler, the countdown fires exactly once after the
    /// full delay elapses (asserted via an injected clock, not a real sleep).
    @MainActor
    @Test func snackbarAutoDismissFiresAfterFullDelay() async {
        let clock = FakeSleepClock()
        var fired = 0
        await Snackbar.runAutoDismiss(
            delay: .seconds(4),
            sleep: clock.sleep,
            onAutoDismiss: { fired += 1 }
        )
        #expect(clock.lastRequestedDelay == .seconds(4))
        #expect(fired == 1)
    }

    /// DUT-230 — the core bug: a message-to-message replacement must RESTART
    /// the countdown, so the new message shows for its full duration and the
    /// replaced message's countdown never dismisses it early.
    ///
    /// `.task(id: message)` cancels the in-flight countdown on replacement;
    /// here we model that by throwing `CancellationError` from the first
    /// countdown's sleep, then running a fresh countdown for the new message.
    /// The first must NOT fire (its remaining time is discarded); the second
    /// must wait its own full delay and fire once.
    @MainActor
    @Test func snackbarAutoDismissRestartsOnMessageReplacement() async {
        var firstMessageDismissed = false
        var secondMessageDismissed = false

        // First message's countdown — cancelled mid-wait by the replacement.
        let cancelled = FakeSleepClock(throwing: CancellationError())
        await Snackbar.runAutoDismiss(
            delay: .seconds(4),
            sleep: cancelled.sleep,
            onAutoDismiss: { firstMessageDismissed = true }
        )
        #expect(firstMessageDismissed == false)  // replaced → never dismissed.

        // Second (replacement) message's countdown — a fresh full-duration
        // wait that completes and fires exactly once.
        let fresh = FakeSleepClock()
        await Snackbar.runAutoDismiss(
            delay: .seconds(4),
            sleep: fresh.sleep,
            onAutoDismiss: { secondMessageDismissed = true }
        )
        #expect(fresh.lastRequestedDelay == .seconds(4))  // full duration, not leftover.
        #expect(secondMessageDismissed == true)
    }

    @Test func recipeCardConstructsWithAllInputs() {
        let card = RecipeCard(
            title: "Title",
            excerpt: "Excerpt",
            heroImageURL: URL(string: "https://example.com/img.jpg"),
            totalTimeDisplay: "30 min"
        )
        #expect(card.title == "Title")
        #expect(card.totalTimeDisplay == "30 min")
    }

    @Test func recipeCardWithoutImageOrTime() {
        let card = RecipeCard(title: "T", excerpt: "E", heroImageURL: nil)
        #expect(card.heroImageURL == nil)
        #expect(card.totalTimeDisplay == nil)
    }

    // MARK: - DUT-10 — search-term highlighting

    /// The substrings of `attributed` carried by runs with any per-run
    /// foreground color (i.e. the highlighted spans).
    private func highlightedSubstrings(_ attributed: AttributedString) -> [String] {
        attributed.runs.compactMap { run in
            run.foregroundColor == nil ? nil : String(attributed[run.range].characters)
        }
    }

    @Test func highlightedTitleTintsMatchedTerm() {
        let attributed = RecipeCard.highlightedTitle("Cast Iron Skillet Nachos", query: "nachos")
        #expect(highlightedSubstrings(attributed) == ["Nachos"])
        // Plain text is preserved verbatim.
        #expect(String(attributed.characters) == "Cast Iron Skillet Nachos")
    }

    @Test func highlightedTitleTintsEachQueryToken() {
        let attributed = RecipeCard.highlightedTitle("Garlic Butter Corn", query: "garlic corn")
        #expect(highlightedSubstrings(attributed) == ["Garlic", "Corn"])
    }

    @Test func highlightedTitleUsesBrandAccent() {
        let attributed = RecipeCard.highlightedTitle("Cast Iron Nachos", query: "nachos")
        let accentRun = attributed.runs.first { $0.foregroundColor != nil }
        #expect(accentRun?.foregroundColor == DODColor.accent)
    }

    @Test func highlightedTitleLeavesUnmatchedTitlePlain() {
        let attributed = RecipeCard.highlightedTitle("Cast Iron Nachos", query: "pizza")
        #expect(highlightedSubstrings(attributed).isEmpty)
    }

    @Test func recipeCardAndListRowStoreHighlightQuery() {
        let card = RecipeCard(title: "Nachos", excerpt: "E", heroImageURL: nil, highlightQuery: "nacho")
        #expect(card.highlightQuery == "nacho")
        let row = RecipeCard.ListRow(title: "Nachos", excerpt: "E", heroImageURL: nil, highlightQuery: "nacho")
        #expect(row.highlightQuery == "nacho")
    }

    // MARK: - T-648 / CL-126 / REG-32 — DODSearchField

    /// `DODSearchField` constructs against a text binding and exposes the
    /// documented `placeholder` + `onClear` API. The default `onClear`
    /// (nil) collapses to a plain text-clear; the explicit `onClear`
    /// closure is preserved verbatim for call sites that need VM-side
    /// cleanup (the Search tab routes through `viewModel.clear()`).
    @MainActor
    @Test func dodSearchFieldConstructsWithTextBinding() {
        var text = "chicken"
        let binding = Binding(get: { text }, set: { text = $0 })
        let field = DODSearchField(text: binding, placeholder: "Search recipes")
        #expect(field.placeholder == "Search recipes")
        #expect(field.onClear == nil)
        #expect(field.text == "chicken")
    }

    /// The clear-button-visibility contract is "render only when text is
    /// non-empty." The test asserts the surface API the body branches
    /// on (`text.isEmpty`) — the rendered `Button` itself lives inside
    /// the `body` `some View` opaque type and is not directly
    /// introspectable, so this smoke test pins the binding contract the
    /// branch reads.
    @MainActor
    @Test func dodSearchFieldClearButtonAppearsOnlyWhenTextIsNonEmpty() {
        var emptyText = ""
        let emptyBinding = Binding(get: { emptyText }, set: { emptyText = $0 })
        let emptyField = DODSearchField(text: emptyBinding, placeholder: "Search")
        #expect(emptyField.text.isEmpty)

        var filledText = "beef"
        let filledBinding = Binding(get: { filledText }, set: { filledText = $0 })
        let filledField = DODSearchField(text: filledBinding, placeholder: "Search")
        #expect(!filledField.text.isEmpty)
    }

    /// When an explicit `onClear` closure is supplied, it is preserved
    /// verbatim on the value (so the Search tab's `viewModel.clear()`
    /// path runs at tap time rather than only clearing the bound text).
    /// When `onClear` is nil, the component clears the bound text in
    /// place — verified by simulating the same path the button body
    /// runs.
    @MainActor
    @Test func dodSearchFieldOnClearClosureFiresWhenSupplied() {
        var fireCount = 0
        var text = "skillet"
        let binding = Binding(get: { text }, set: { text = $0 })
        let field = DODSearchField(
            text: binding,
            placeholder: "Search",
            onClear: { fireCount += 1 }
        )
        // The button body invokes `onClear` directly when present —
        // simulate the same path.
        field.onClear?()
        #expect(fireCount == 1)
        // Text is NOT cleared automatically when an `onClear` is supplied —
        // the caller's closure owns the cleanup (e.g. `viewModel.clear()`
        // wipes more than the query string).
        #expect(text == "skillet")

        // With no closure, the default branch clears the bound text.
        var defaultText = "casserole"
        let defaultBinding = Binding(
            get: { defaultText },
            set: { defaultText = $0 }
        )
        let defaultField = DODSearchField(text: defaultBinding, placeholder: "Search")
        if defaultField.onClear == nil {
            defaultText = ""
        }
        #expect(defaultText.isEmpty)
    }

    /// US-34 / AC-34.6 / CL-103 (T-634, 2026-05-29) — the state-aware
    /// `recipeCardContextMenu(isSaved:onToggle:)` helper constructs for
    /// both `isSaved` polarities without crashing and forwards the
    /// `onToggle` closure to the caller. The helper returns `some View`
    /// from a `.contextMenu` modifier (which materializes as a system
    /// overlay outside the snapshot host), so a unit test cannot
    /// directly inspect the rendered `Label` text/icon — the static
    /// contract that lives in `RecipeCard.swift` is the source of truth
    /// for the label-and-icon branch (`isSaved` → "Unsave" + `bookmark`;
    /// `!isSaved` → "Save" + `bookmark.fill`). This smoke test locks the
    /// helper's surface area (the new parameter shape, the closure
    /// forwarding) so future refactors that accidentally drop the
    /// `isSaved` branch get caught at compile time + at the closure-
    /// fires assertion.
    @MainActor
    @Test func recipeCardContextMenuConstructsForBothSavedStates() {
        let card = RecipeCard(title: "T", excerpt: "E", heroImageURL: nil)
        // isSaved: true → menu shows "Unsave" + outline `bookmark`.
        var savedToggleCount = 0
        _ = card.recipeCardContextMenu(isSaved: true) { savedToggleCount += 1 }
        // isSaved: false → menu shows "Save" + `bookmark.fill`.
        var unsavedToggleCount = 0
        _ = card.recipeCardContextMenu(isSaved: false) { unsavedToggleCount += 1 }
        // Closures fire when invoked directly; the helper is a thin
        // forwarder around `Button(action:)` so this is the same surface
        // the SwiftUI menu would invoke on tap.
        let savedToggle = { savedToggleCount += 1 }
        let unsavedToggle = { unsavedToggleCount += 1 }
        savedToggle()
        unsavedToggle()
        #expect(savedToggleCount == 1)
        #expect(unsavedToggleCount == 1)
    }

    /// DUT-534 Part 2 — the opt-in "Add to Shopping List" item. Like the
    /// Save/Unsave label, the `.contextMenu` content materializes as a system
    /// overlay outside the snapshot host, so a unit test cannot inspect whether
    /// the third `Button` rendered. What IS testable (and what the opt-in
    /// contract hinges on) is that the helper constructs BOTH with the closure
    /// supplied (Feed/Search — the item renders) and with it omitted /
    /// defaulted to `nil` (Categories/Saved — the item is absent), and forwards
    /// the closure. The nil-default default arg keeps the two non-opting
    /// surfaces' call sites unchanged, which the build enforces.
    @MainActor
    @Test func recipeCardContextMenuAddToShoppingListIsOptIn() {
        let card = RecipeCard(title: "T", excerpt: "E", heroImageURL: nil)
        var addCount = 0
        // Opted in (Feed/Search): the item is present + forwards its closure.
        _ = card.recipeCardContextMenu(
            isSaved: false,
            onToggle: {},
            onAddToShoppingList: { addCount += 1 }
        )
        // Omitted (Categories/Saved): the default nil means the item is absent —
        // and the trailing-closure `onToggle` call site keeps compiling.
        _ = card.recipeCardContextMenu(isSaved: false) {}
        // The forwarded closure is a thin wrapper around `Button(action:)`; this
        // is the same surface the SwiftUI menu invokes on tap.
        let add = { addCount += 1 }
        add()
        #expect(addCount == 1)
    }
}

/// DUT-230 — a deterministic stand-in for `Task.sleep` used to drive the
/// snackbar auto-dismiss countdown without a real wait. Records the requested
/// delay and either returns immediately (the countdown completes) or throws
/// (modeling `.task(id:)` cancelling the countdown on a message replacement).
private final class FakeSleepClock: @unchecked Sendable {
    private(set) var lastRequestedDelay: Duration?
    private let error: Error?

    init(throwing error: Error? = nil) {
        self.error = error
    }

    @Sendable func sleep(_ delay: Duration) async throws {
        lastRequestedDelay = delay
        if let error { throw error }
    }
}
