#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODDesignSystem

/// L4 visual-regression tests for DesignSystem components.
///
/// First run with `record: true` creates baseline PNGs under
/// `__Snapshots__/`. Subsequent runs diff against those baselines and fail
/// with a pixel diff if anything moves. Intentional visual changes are
/// approved by re-recording and committing the new PNGs.
///
/// Spec trace: constitution §6 L4, AC-T1 ("PR runs L4").
final class DesignSystemSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to refresh baselines after an intentional
        // visual change, then revert before commit.
        isRecording = false
    }

    func test_emptyState_default() {
        let view = EmptyState(title: "No saved recipes yet", message: "Tap the heart on any recipe.")
            .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 600)))
    }

    func test_emptyState_withAction() {
        let view = EmptyState(
            title: "You need internet",
            message: "Connect to load recipes.",
            action: .init(title: "Retry") {}
        )
        .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 600)))
    }

    func test_offlineBanner_offline() {
        let view = OfflineBanner(isOffline: true)
            .frame(width: 390, height: 60)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 60)))
    }

    func test_snackbar_plain() {
        let view = Snackbar(message: "Recipe unavailable.")
            .frame(width: 390, height: 80)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 80)))
    }

    func test_snackbar_withUndo() {
        let view = Snackbar(message: "Removed from saved.", action: .init(title: "Undo") {})
            .frame(width: 390, height: 80)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 80)))
    }

    func test_recipeCard_full() {
        let view = RecipeCard(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
        .frame(width: 358)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    func test_recipeCard_noTimeChip() {
        let view = RecipeCard(
            title: "Sourdough Bread",
            excerpt: "Crusty, chewy, slow-fermented.",
            heroImageURL: nil
        )
        .frame(width: 358)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    /// Exercise RecipeCard at the new ~180pt half-width — the size each card
    /// occupies in the 2-column iPhone grid introduced by the CC-9
    /// amendment. Guards against title/excerpt truncation issues that
    /// don't surface at the full-width 358pt layout.
    func test_recipeCard_halfWidth() {
        let view = RecipeCard(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
        .frame(width: 180)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    /// US-8 first-launch welcome sheet. iPhone 17 logical size is 402×874pt;
    /// rendering at .large detent fills (nearly) the full screen and gives
    /// us a stable baseline to diff against on layout changes.
    func test_onboardingSheet_default() {
        let view = OnboardingSheet(
            title: "Welcome to Dutch Oven Daddy",
            bullets: [
                .init(
                    systemImage: "house.fill",
                    title: "Browse the latest",
                    caption: "New cast iron recipes appear at the top."
                ),
                .init(
                    systemImage: "magnifyingglass",
                    title: "Search what you've got",
                    caption: "Type any ingredient or technique to filter."
                ),
                .init(
                    systemImage: "heart.fill",
                    title: "Save for offline",
                    caption: "Tap the heart on any recipe to cook it without Wi-Fi."
                ),
            ],
            ctaTitle: "Get cooking",
            onContinue: {}
        )
        .frame(width: 402, height: 874)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 402, height: 874)))
    }

    // MARK: - US-9 home-screen widget
    //
    // First-time record: the harness writes a baseline PNG under
    // `__Snapshots__/SnapshotTests/<testName>.png` and reports the test as
    // failed (so devs notice). Subsequent runs diff and pass when stable.
    // The existing tests above were recorded the same way; nothing special
    // about these.

    /// REG-9.1: small widget layout at 158×158pt (iPhone 17 small system
    /// widget size). Pins the gradient + chip + title arrangement so
    /// future changes to typography or hero treatment surface in diff.
    func test_widgetCard_small_populated() {
        let view = WidgetCard.Small(
            content: .init(
                title: "Garlic Butter Skillet Corn",
                excerpt: "An easy 15-minute side dish that pairs with everything.",
                heroImageURL: nil,
                totalTimeDisplay: "15 min"
            )
        )
        .frame(width: 158, height: 158)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 158, height: 158)), record: .missing)
    }

    /// REG-9.2: medium widget layout at 338×158pt (iPhone 17 medium
    /// system widget size).
    func test_widgetCard_medium_populated() {
        let view = WidgetCard.Medium(
            content: .init(
                title: "Garlic Butter Skillet Corn",
                excerpt: "An easy 15-minute side dish that pairs with everything.",
                heroImageURL: nil,
                totalTimeDisplay: "15 min"
            )
        )
        .frame(width: 338, height: 158)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 338, height: 158)), record: .missing)
    }

    /// REG-9.3: placeholder layout for when the App Group store has no
    /// snapshot yet (first launch). AC-9.4.
    func test_widgetCard_placeholder() {
        let view = WidgetCard.Placeholder()
            .frame(width: 158, height: 158)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 158, height: 158)), record: .missing)
    }

    // MARK: - US-13 / US-14 / US-15 comments + ratings + guest identity
    //
    // Light mode only — matches the existing convention above. Dark-mode
    // baselines would double the file count for marginal coverage gain.
    // Record-on-missing so first runs lay down baselines instead of failing.

    func test_starRatingDisplay_4point5_stars_27_count() {
        let view = StarRatingDisplay(average: 4.5, count: 27)
            .padding(DODSpacing.md)
            .background(DODColor.surface)
            .frame(width: 280, height: 60)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 280, height: 60)), record: .missing)
    }

    /// Empty count → EmptyView; we wrap in a parent to prove "nothing"
    /// renders between two adjacent texts. AC: caller decides fallback.
    func test_starRatingDisplay_zeroCountIsEmpty() {
        let view = VStack(spacing: 4) {
            Text("Above")
            StarRatingDisplay(average: 0, count: 0)
            Text("Below")
        }
        .padding(DODSpacing.md)
        .background(DODColor.surface)
        .frame(width: 280, height: 100)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 280, height: 100)), record: .missing)
    }

    func test_starRatingInput_zero() {
        let view = StatefulInputHost(initial: 0)
            .padding(DODSpacing.md)
            .background(DODColor.surface)
            .frame(width: 320, height: 80)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 320, height: 80)), record: .missing)
    }

    func test_starRatingInput_threeStarsSelected() {
        let view = StatefulInputHost(initial: 3)
            .padding(DODSpacing.md)
            .background(DODColor.surface)
            .frame(width: 320, height: 80)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 320, height: 80)), record: .missing)
    }

    func test_commentRow_withAvatarAndRating() {
        let view = CommentRow(
            authorName: "Jamie L.",
            avatarURL: nil,
            relativeDate: "3 days ago",
            bodyText:
                "Made this last night and it was incredible. Subbed smoked paprika for the regular kind and it added a great depth.",
            ratingValue: 5
        )
        .padding(DODSpacing.md)
        .background(DODColor.surface)
        .frame(width: 390)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits), record: .missing)
    }

    func test_commentRow_pendingModeration() {
        let view = CommentRow(
            authorName: "You",
            avatarURL: nil,
            relativeDate: "Just now",
            bodyText: "Question — can I sub butter for the oil?",
            ratingValue: 4,
            isPendingModeration: true
        )
        .padding(DODSpacing.md)
        .background(DODColor.surface)
        .frame(width: 390)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits), record: .missing)
    }

    /// 600-character body — ensures layout stays sane when a comment is
    /// long enough to multi-line wrap several times. No truncation; let
    /// the row grow vertically.
    func test_commentRow_longBodyTruncates() {
        let longBody = String(
            repeating: "This is a long comment body that should wrap many times within the row. ",
            count: 9
        )
        .prefix(600)
        let view = CommentRow(
            authorName: "Pat M.",
            avatarURL: nil,
            relativeDate: "1 week ago",
            bodyText: String(longBody),
            ratingValue: 5
        )
        .padding(DODSpacing.md)
        .background(DODColor.surface)
        .frame(width: 390)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits), record: .missing)
    }

    func test_commentComposer_emptyState() {
        let view = StatefulComposerHost(text: "", rating: 0, isSubmitting: false)
            .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 600)), record: .missing)
    }

    func test_commentComposer_filledState() {
        let view = StatefulComposerHost(
            text: "Made this for Sunday dinner and the whole family went back for seconds.",
            rating: 5,
            isSubmitting: false
        )
        .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 600)), record: .missing)
    }

    func test_guestIdentitySheet_empty() {
        let view = StatefulIdentityHost(name: "", email: "")
            .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 600)), record: .missing)
    }

    func test_guestIdentitySheet_filledValid() {
        let view = StatefulIdentityHost(name: "Jamie L.", email: "jamie@example.com")
            .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 600)), record: .missing)
    }

    func test_moderationBadge_eachKind() {
        let view = VStack(alignment: .leading, spacing: DODSpacing.sm) {
            ModerationBadge(kind: .awaitingApproval)
            ModerationBadge(kind: .posted)
            ModerationBadge(kind: .failed)
        }
        .padding(DODSpacing.md)
        .background(DODColor.surface)
        .frame(width: 280, height: 180)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 280, height: 180)), record: .missing)
    }
}

// MARK: - Stateful hosts
//
// `@State`-bound views need a real conforming type — preview helpers in
// the source files are `private`, so we re-declare equivalent shells here
// for the snapshot harness.

private struct StatefulInputHost: View {
    @State var value: Int
    init(initial: Int) { _value = State(initialValue: initial) }
    var body: some View { StarRatingInput(value: $value) }
}

private struct StatefulComposerHost: View {
    @State var text: String
    @State var rating: Int
    let isSubmitting: Bool

    init(text: String, rating: Int, isSubmitting: Bool) {
        _text = State(initialValue: text)
        _rating = State(initialValue: rating)
        self.isSubmitting = isSubmitting
    }

    var body: some View {
        CommentComposer(
            text: $text,
            rating: $rating,
            isSubmitting: isSubmitting,
            onSubmit: {},
            onCancel: {}
        )
    }
}

private struct StatefulIdentityHost: View {
    @State var name: String
    @State var email: String

    init(name: String, email: String) {
        _name = State(initialValue: name)
        _email = State(initialValue: email)
    }

    var body: some View {
        GuestIdentitySheet(
            displayName: $name,
            email: $email,
            isSubmitting: false,
            onContinue: {}
        )
    }
}
#endif
