import SwiftUI

/// The first-launch **App Intro** as a single, non-paged welcome screen
/// (DUT-1089, CL-327 — replaces the swipeable `AppIntroTour` from DUT-335 +
/// its DUT-336 media). One screen: the brand badge, a Title-Case headline, one
/// intro sentence, a short bulleted feature list, and a persistent
/// "Let's Get Cooking" CTA. No Next/Back, no page dots, no video, no
/// screenshots.
///
/// Built generic so the hosting app supplies the copy + bullets + CTA, keeping
/// DesignSystem decoupled from product strings (same contract as `AppIntroTour`).
public struct AppIntroWelcome: View {

    /// One feature bullet: an SF Symbol, a Title-Case label, and a sentence-case
    /// one-liner.
    public struct Bullet: Identifiable, Sendable {
        public let id: Int
        public let icon: String
        public let title: String
        public let detail: String

        public init(id: Int, icon: String, title: String, detail: String) {
            self.id = id
            self.icon = icon
            self.title = title
            self.detail = detail
        }
    }

    private let headline: String
    private let intro: String
    private let bullets: [Bullet]
    private let ctaTitle: String
    private let onFinish: @MainActor () -> Void

    public init(
        headline: String,
        intro: String,
        bullets: [Bullet],
        ctaTitle: String,
        onFinish: @MainActor @escaping () -> Void
    ) {
        self.headline = headline
        self.intro = intro
        self.bullets = bullets
        self.ctaTitle = ctaTitle
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DODSpacing.lg) {
                    // Brand badge — decorative; the headline carries the label.
                    DODBrandMark(size: 88)
                        .padding(.top, DODSpacing.xl)

                    VStack(spacing: DODSpacing.sm) {
                        Text(headline)
                            .dodFont(DODType.displayLarge)
                            .foregroundStyle(DODColor.label)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(intro)
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.labelSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: DODSpacing.md) {
                        ForEach(bullets) { bulletRow($0) }
                    }
                    .padding(.top, DODSpacing.xs)
                }
                .padding(.horizontal, DODSpacing.xl)
                .padding(.bottom, DODSpacing.lg)
                // Cap to a centered reading column so the full-screen cover
                // doesn't stretch to an unreadable measure on iPad (matches the
                // former `AppIntroTour` 500pt cap; compact/iPhone is unaffected).
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            ctaButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DODColor.surface.ignoresSafeArea())
    }

    private func bulletRow(_ bullet: Bullet) -> some View {
        HStack(alignment: .top, spacing: DODSpacing.md) {
            Image(systemName: bullet.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DODColor.accent)
                .frame(width: 32, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text(bullet.title)
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.label)
                Text(bullet.detail)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Read the icon's meaning through the title, so VoiceOver hears one
        // coherent "title, detail" element per bullet.
        .accessibilityElement(children: .combine)
    }

    private var ctaButton: some View {
        Button(action: onFinish) {
            Text(ctaTitle)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DODSpacing.md)
                // CL-304 / DUT-537 — a button takes the pill tier (`Capsule`).
                .background(Capsule(style: .continuous).fill(DODColor.accent))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DODSpacing.xl)
        .padding(.top, DODSpacing.sm)
        .padding(.bottom, DODSpacing.lg)
        .frame(maxWidth: 500)
        .accessibilityIdentifier("app-intro-cta")
    }
}

#Preview("App Intro Welcome") {
    AppIntroWelcome(
        headline: "Welcome to Dutch Oven Daddy",
        intro: "Your guide from your first cookout to cast iron hero.",
        bullets: [
            .init(
                id: 0,
                icon: "square.grid.2x2.fill",
                title: "Browse Recipes & Articles",
                detail: "Fresh cast iron recipes to cook and articles to read, all in one place."
            ),
            .init(
                id: 1,
                icon: "bookmark.fill",
                title: "Save Your Favorites",
                detail: "Bookmark any recipe and find it again in a tap."
            ),
            .init(
                id: 2,
                icon: "speaker.wave.2.fill",
                title: "Cook Mode",
                detail: "One step at a time, with large text and voice read-aloud."
            ),
        ],
        ctaTitle: "Let's Get Cooking",
        onFinish: {}
    )
}
