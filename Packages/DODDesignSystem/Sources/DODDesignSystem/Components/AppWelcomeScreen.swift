import SwiftUI

/// The first-launch **App Welcome**: a single, scrollable screen that shows the
/// brand badge, a headline, one intro sentence, and a bulleted tour of what the
/// app does — with a persistent CTA pinned below the scroll.
///
/// DUT-2896 (v2) — the bullets can sit under an optional `sectionTitle` ("New in
/// 2.0"), and a bullet can carry a small inline ``BulletAction`` button (the
/// Seasoned Cast Iron "Try It").
///
/// Built generic so the hosting app supplies the copy + CTA; DesignSystem stays
/// decoupled from product strings.
///
/// Spec trace: US-8 (amended by DUT-335 — the single-screen `OnboardingSheet`
/// became a paged tour; this collapses that paged tour back to ONE screen).
/// The paged `TabView`, Next/Back nav, page dots, and the per-slide video/image
/// media plumbing are all gone: the bullets carry the story, so there is nothing
/// left to page through.
public struct AppWelcomeScreen: View {

    /// One feature bullet. `symbol` is the SF Symbol shown in the leading icon
    /// slot; `title` is Title Case and `description` is sentence case.
    public struct Bullet: Identifiable, Sendable {
        public let id: Int
        /// Title Case label, e.g. "Cook Mode".
        public let title: String
        /// Sentence-case blurb (a sentence or two — not a wall of text).
        public let description: String
        public let symbol: String
        /// DUT-2896 — an optional inline button under the description.
        public let action: BulletAction?

        public init(id: Int, title: String, description: String, symbol: String, action: BulletAction? = nil) {
            self.id = id
            self.title = title
            self.description = description
            self.symbol = symbol
            self.action = action
        }
    }

    /// DUT-2896 — a small pill button under a bullet (e.g. "Try It" on the new
    /// theme). Once `isActive`, it reads `activeTitle` with a checkmark and is
    /// disabled, so the user can see the tap took.
    public struct BulletAction: Sendable {
        /// Title Case, e.g. "Try It".
        public let title: String
        /// Title Case, shown once applied, e.g. "Selected".
        public let activeTitle: String
        public let isActive: Bool
        public let accessibilityIdentifier: String
        public let perform: @MainActor @Sendable () -> Void

        public init(
            title: String,
            activeTitle: String,
            isActive: Bool,
            accessibilityIdentifier: String,
            perform: @MainActor @Sendable @escaping () -> Void
        ) {
            self.title = title
            self.activeTitle = activeTitle
            self.isActive = isActive
            self.accessibilityIdentifier = accessibilityIdentifier
            self.perform = perform
        }
    }

    /// Title Case headline, e.g. "Welcome to Dutch Oven Daddy".
    public let headline: String
    /// One sentence setting up the bullets below.
    public let intro: String
    /// DUT-2896 — an optional Title Case heading above the bullets ("New in 2.0").
    public let sectionTitle: String?
    public let bullets: [Bullet]
    /// An optional standing disclosure, pinned ABOVE the CTA and OUTSIDE the
    /// scroll so it is always on screen.
    ///
    /// This is deliberately not a bullet. It carries the kind of statement the
    /// user must actually see before tapping the CTA (today: that iCloud Sync is
    /// on by default), and a bullet at the bottom of a scrolling list can be
    /// tapped past without ever being read — which would make the disclosure
    /// decorative rather than real.
    public let disclosure: String?
    /// The persistent finish button label, e.g. "Let's Get Cooking".
    public let ctaTitle: String
    public let onFinish: @MainActor () -> Void

    public init(
        headline: String,
        intro: String,
        sectionTitle: String? = nil,
        bullets: [Bullet],
        disclosure: String? = nil,
        ctaTitle: String,
        onFinish: @MainActor @escaping () -> Void
    ) {
        self.headline = headline
        self.intro = intro
        self.sectionTitle = sectionTitle
        self.bullets = bullets
        self.disclosure = disclosure
        self.ctaTitle = ctaTitle
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(spacing: DODSpacing.lg) {
            // The bullets + the badge overflow every iPhone at accessibility
            // text sizes, so the content column scrolls while the disclosure
            // and the CTA stay pinned and always reachable.
            ScrollView {
                VStack(spacing: DODSpacing.xl) {
                    header
                    bulletList
                }
                .padding(.horizontal, DODSpacing.xl)
                .padding(.top, DODSpacing.xl)
                .padding(.bottom, DODSpacing.lg)
                // Cap the reading measure so the `.fullScreenCover` doesn't
                // stretch body text to an unreadable width on iPad. The 500pt
                // cap exceeds the widest iPhone content region, so compact /
                // iPhone stays byte-identical.
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            disclosureLine
            ctaButton
        }
        .padding(.bottom, DODSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DODColor.surface.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DODSpacing.md) {
            // The Dutch Oven Daddy badge sits on a soft `cream` circle so it
            // reads as a self-contained coin on BOTH appearances — `cream`
            // stays light in dark mode, so the espresso ring keeps its
            // contrast. Decorative: the headline carries the meaning.
            Image("dod-logo-badge", bundle: .module)
                .resizable()
                .scaledToFit()
                .padding(DODSpacing.md)
                .background(Circle().fill(DODColor.cream))
                .frame(maxWidth: 160)
                .accessibilityHidden(true)
            Text(headline)
                .dodFont(DODType.displayLarge)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
                // Let the headline grow vertically so it wraps instead of
                // truncating at large Dynamic Type sizes (DUT-694).
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(intro)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Bullets

    private var bulletList: some View {
        VStack(alignment: .leading, spacing: DODSpacing.lg) {
            if let sectionTitle {
                Text(sectionTitle)
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(bullets) { bullet in
                bulletRow(bullet)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bulletRow(_ bullet: Bullet) -> some View {
        HStack(alignment: .top, spacing: DODSpacing.md) {
            // Accent lives on the small icon only (never a full content-card
            // fill) — the burnt-orange convention.
            Image(systemName: bullet.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DODColor.accent)
                .frame(width: 32, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text(bullet.title)
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text(bullet.description)
                    .dodFont(DODType.detail)
                    .foregroundStyle(DODColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let action = bullet.action {
                    actionButton(action)
                        .padding(.top, DODSpacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // One VoiceOver stop per bullet ("Cook Mode, Cook one step at a time…"),
        // but a bullet with a button keeps the button its own stop.
        .accessibilityElement(children: bullet.action == nil ? .combine : .contain)
    }

    /// DUT-2896 — the pill under a bullet. A control, so it takes the Capsule
    /// tier (CL-304); accent is a small pill fill, never a card fill.
    private func actionButton(_ action: BulletAction) -> some View {
        Button {
            guard !action.isActive else { return }
            action.perform()
        } label: {
            HStack(spacing: DODSpacing.xs) {
                if action.isActive {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
                Text(action.isActive ? action.activeTitle : action.title)
            }
            .dodFont(DODType.bodyEmphasized)
            .foregroundStyle(action.isActive ? DODColor.accent : DODColor.cream)
            .padding(.horizontal, DODSpacing.lg)
            .padding(.vertical, DODSpacing.xs)
            .frame(minHeight: 44)
            // Applied: an accent outline instead of the fill. Not `.disabled`,
            // which would dim it to near-invisible on the true-black theme.
            .background(
                Capsule(style: .continuous)
                    .fill(action.isActive ? Color.clear : DODColor.accent)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(DODColor.accent, lineWidth: action.isActive ? 1.5 : 0)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: action.isActive)
        .accessibilityIdentifier(action.accessibilityIdentifier)
        .accessibilityAddTraits(action.isActive ? .isSelected : [])
    }

    // MARK: - CTA

    /// The standing disclosure, directly above the CTA and outside the scroll so
    /// it can't be tapped past unread. Quiet (caption / secondary) so it informs
    /// without competing with the CTA.
    @ViewBuilder
    private var disclosureLine: some View {
        if let disclosure {
            Text(disclosure)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DODSpacing.xl)
                .frame(maxWidth: 500)
                .accessibilityIdentifier("app-intro-disclosure")
        }
    }

    private var ctaButton: some View {
        Button(action: onFinish) {
            Text(ctaTitle)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DODSpacing.md)
                // CL-304 / DUT-537: the CTA is a button, so it takes the pill
                // tier (`Capsule`), not the card-tier `DODRadius.standard`.
                .background(
                    Capsule(style: .continuous)
                        .fill(DODColor.accent)
                )
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DODSpacing.xl)
        .frame(maxWidth: 500)
        .accessibilityIdentifier("app-intro-cta")
    }
}

#Preview("App Welcome") {
    AppWelcomeScreen(
        headline: "Welcome to Dutch Oven Daddy",
        intro: "New to cast iron? You're in the right place. Here's what's inside.",
        bullets: [
            .init(
                id: 0,
                title: "Browse Recipes & Articles",
                description: "Fresh cast iron recipes to cook and articles to read, all in one tab.",
                symbol: "square.grid.2x2.fill"
            ),
            .init(
                id: 1,
                title: "Cook Mode",
                description: "Cook one step at a time with large text and voice read-aloud.",
                symbol: "speaker.wave.2.fill"
            ),
        ],
        ctaTitle: "Let's Get Cooking",
        onFinish: {}
    )
}
