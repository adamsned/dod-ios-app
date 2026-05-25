#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODDesignSystem

/// Dark-mode and AX5 Dynamic Type baselines for DesignSystem components.
///
/// Lives in a sibling test class to `DesignSystemSnapshotTests` so the
/// original file stays under SwiftLint's 600-line cap; everything below
/// pairs 1:1 with a `test_*` over there. The split is mechanical, not
/// semantic.
///
/// `record: .missing` lays the PNG down on first iOS test run. No PNGs
/// are committed by T-330 itself — that's the T-331 follow-up. See
/// `specs/dod-ios-app/appearance-audit.md` for the audit framing.
///
/// Spec trace: constitution §6 L4, §7 (WCAG AA in both appearances),
/// US-18 AC-18.1, AC-18.2.
final class DesignSystemAppearanceSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    // MARK: - Dark-mode variants
    //
    // Each method pairs 1:1 with a light test in `DesignSystemSnapshotTests`
    // — the only visual delta is `userInterfaceStyle = .dark`.

    func test_emptyState_default_dark() {
        let view = EmptyState(title: "No saved recipes yet", message: "Tap the bookmark on any recipe.")
            .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: Self.darkImage(width: 390, height: 600), record: .missing)
    }

    func test_emptyState_withAction_dark() {
        let view = EmptyState(
            title: "You need internet",
            message: "Connect to load recipes.",
            action: .init(title: "Retry") {}
        )
        .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: Self.darkImage(width: 390, height: 600), record: .missing)
    }

    func test_offlineBanner_offline_dark() {
        let view = OfflineBanner(isOffline: true)
            .frame(width: 390, height: 60)
        assertSnapshot(of: view, as: Self.darkImage(width: 390, height: 60), record: .missing)
    }

    func test_snackbar_plain_dark() {
        let view = Snackbar(message: "Recipe unavailable.")
            .frame(width: 390, height: 80)
        assertSnapshot(of: view, as: Self.darkImage(width: 390, height: 80), record: .missing)
    }

    func test_snackbar_withUndo_dark() {
        let view = Snackbar(message: "Removed from saved.", action: .init(title: "Undo") {})
            .frame(width: 390, height: 80)
        assertSnapshot(of: view, as: Self.darkImage(width: 390, height: 80), record: .missing)
    }

    func test_recipeCard_full_dark() {
        let view = RecipeCard(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
        .frame(width: 358)
        assertSnapshot(
            of: view,
            as: .image(layout: .sizeThatFits, traits: Self.darkTraits()),
            record: .missing
        )
    }

    func test_recipeCard_halfWidth_dark() {
        let view = RecipeCard(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
        .frame(width: 180)
        assertSnapshot(
            of: view,
            as: .image(layout: .sizeThatFits, traits: Self.darkTraits()),
            record: .missing
        )
    }

    func test_onboardingSheet_default_dark() {
        let view = OnboardingSheet(
            title: "Welcome to Dutch Oven Daddy",
            bullets: Self.onboardingBullets(),
            ctaTitle: "Get cooking",
            onContinue: {}
        )
        .frame(width: 402, height: 874)
        assertSnapshot(of: view, as: Self.darkImage(width: 402, height: 874), record: .missing)
    }

    func test_widgetCard_small_populated_dark() {
        let view = WidgetCard.Small(content: Self.widgetContent())
            .frame(width: 158, height: 158)
        assertSnapshot(of: view, as: Self.darkImage(width: 158, height: 158), record: .missing)
    }

    func test_widgetCard_medium_populated_dark() {
        let view = WidgetCard.Medium(content: Self.widgetContent())
            .frame(width: 338, height: 158)
        assertSnapshot(of: view, as: Self.darkImage(width: 338, height: 158), record: .missing)
    }

    func test_widgetCard_placeholder_dark() {
        let view = WidgetCard.Placeholder()
            .frame(width: 158, height: 158)
        assertSnapshot(of: view, as: Self.darkImage(width: 158, height: 158), record: .missing)
    }

    func test_starRatingDisplay_4point5_stars_27_count_dark() {
        let view = StarRatingDisplay(average: 4.5, count: 27)
            .padding(DODSpacing.md)
            .background(DODColor.surface)
            .frame(width: 280, height: 60)
        assertSnapshot(of: view, as: Self.darkImage(width: 280, height: 60), record: .missing)
    }

    func test_starRatingInput_threeStarsSelected_dark() {
        let view = AuditStatefulInputHost(initial: 3)
            .padding(DODSpacing.md)
            .background(DODColor.surface)
            .frame(width: 320, height: 80)
        assertSnapshot(of: view, as: Self.darkImage(width: 320, height: 80), record: .missing)
    }

    func test_commentRow_withAvatarAndRating_dark() {
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
        assertSnapshot(
            of: view,
            as: .image(layout: .sizeThatFits, traits: Self.darkTraits()),
            record: .missing
        )
    }

    func test_commentComposer_filledState_dark() {
        let view = AuditStatefulComposerHost(
            text: "Made this for Sunday dinner and the whole family went back for seconds.",
            rating: 5,
            isSubmitting: false
        )
        .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: Self.darkImage(width: 390, height: 600), record: .missing)
    }

    func test_guestIdentitySheet_filledValid_dark() {
        let view = AuditStatefulIdentityHost(name: "Jamie L.", email: "jamie@example.com")
            .frame(width: 390, height: 600)
        assertSnapshot(of: view, as: Self.darkImage(width: 390, height: 600), record: .missing)
    }

    func test_moderationBadge_eachKind_dark() {
        let view = VStack(alignment: .leading, spacing: DODSpacing.sm) {
            ModerationBadge(kind: .awaitingApproval)
            ModerationBadge(kind: .posted)
            ModerationBadge(kind: .failed)
        }
        .padding(DODSpacing.md)
        .background(DODColor.surface)
        .frame(width: 280, height: 180)
        assertSnapshot(of: view, as: Self.darkImage(width: 280, height: 180), record: .missing)
    }

    // MARK: - AX5 Dynamic Type variants
    //
    // Sampled on the components where Dynamic Type scaling matters most
    // (text-heavy, multi-line layouts). Larger fixed-height frames
    // accommodate AX5 wrap without truncating. Light appearance — the
    // dark × AX5 cell is documented in the audit as deferred (combinatorial
    // explosion not worth the baseline surface area for v1.0).

    func test_recipeCard_full_AX5() {
        let view = RecipeCard(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
        .frame(width: 358)
        assertSnapshot(
            of: view,
            as: .image(layout: .sizeThatFits, traits: Self.ax5Traits()),
            record: .missing
        )
    }

    func test_emptyState_withAction_AX5() {
        let view = EmptyState(
            title: "You need internet",
            message: "Connect to load recipes.",
            action: .init(title: "Retry") {}
        )
        .frame(width: 390, height: 1_200)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 1_200), traits: Self.ax5Traits()),
            record: .missing
        )
    }

    func test_commentRow_withAvatarAndRating_AX5() {
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
        assertSnapshot(
            of: view,
            as: .image(layout: .sizeThatFits, traits: Self.ax5Traits()),
            record: .missing
        )
    }

    func test_onboardingSheet_default_AX5() {
        let view = OnboardingSheet(
            title: "Welcome to Dutch Oven Daddy",
            bullets: Self.onboardingBullets(),
            ctaTitle: "Get cooking",
            onContinue: {}
        )
        .frame(width: 402, height: 1_800)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 402, height: 1_800), traits: Self.ax5Traits()),
            record: .missing
        )
    }

    // MARK: - Trait helpers

    /// `UITraitCollection` that forces dark appearance at @3x scale.
    private static func darkTraits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(displayScale: 3),
        ])
    }

    /// `UITraitCollection` at AX5 Dynamic Type (the largest accessibility
    /// size) at @3x scale.
    private static func ax5Traits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            UITraitCollection(displayScale: 3),
        ])
    }

    /// Convenience for the common "fixed size, dark appearance" pairing.
    private static func darkImage<V: View>(width: CGFloat, height: CGFloat) -> Snapshotting<V, UIImage> {
        .image(layout: .fixed(width: width, height: height), traits: darkTraits())
    }

    // MARK: - Fixture helpers

    private static func widgetContent() -> WidgetCard.Content {
        WidgetCard.Content(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
    }

    private static func onboardingBullets() -> [OnboardingSheet.Bullet] {
        [
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
                systemImage: "bookmark.fill",
                title: "Save for offline",
                caption: "Tap the bookmark on any recipe to cook it without Wi-Fi."
            ),
        ]
    }
}

// MARK: - Stateful hosts
//
// The original `StatefulInputHost` / `StatefulComposerHost` / `StatefulIdentityHost`
// in `SnapshotTests.swift` are `private` — re-declare equivalents here so this
// file is self-contained and the split stays mechanical.

private struct AuditStatefulInputHost: View {
    @State var value: Int
    init(initial: Int) { _value = State(initialValue: initial) }
    var body: some View { StarRatingInput(value: $value) }
}

private struct AuditStatefulComposerHost: View {
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

private struct AuditStatefulIdentityHost: View {
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
