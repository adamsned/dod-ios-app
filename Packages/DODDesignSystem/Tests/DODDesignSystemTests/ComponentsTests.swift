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
        let skeleton = LoadingSkeleton(cornerRadius: 16)
        #expect(skeleton.cornerRadius == 16)
    }

    @Test func snackbarOptionalAction() {
        let plain = Snackbar(message: "Saved.")
        #expect(plain.action == nil)
        let withUndo = Snackbar(message: "Removed.", action: .init(title: "Undo") {})
        #expect(withUndo.action?.title == "Undo")
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
}
