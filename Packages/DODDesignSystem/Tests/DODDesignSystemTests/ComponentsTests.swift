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
}
