import SwiftUI

/// One-screen welcome sheet shown on first launch. Built generic so the
/// hosting app supplies the copy, icon set, and CTA — DesignSystem stays
/// decoupled from product strings.
///
/// Spec trace: US-8 (post-launch amendment to CL-7). The original spec
/// shipped without onboarding; we now want a single Apple-style "here's
/// what this app does" screen so new installs aren't dropped cold into
/// the feed.
public struct OnboardingSheet: View {

    /// One row of the three-bullet rundown. `systemImage` is an SF Symbol
    /// name (e.g. `house.fill`, `magnifyingglass`, `bookmark.fill`).
    public struct Bullet: Identifiable {
        public let id: String
        public let systemImage: String
        public let title: String
        public let caption: String

        public init(systemImage: String, title: String, caption: String) {
            // Title is sufficiently unique within a single onboarding view
            // — same identity rule as a SwiftUI ForEach over `\.self`.
            self.id = title
            self.systemImage = systemImage
            self.title = title
            self.caption = caption
        }
    }

    public let title: String
    public let bullets: [Bullet]
    public let ctaTitle: String
    public let onContinue: @MainActor () -> Void

    public init(
        title: String,
        bullets: [Bullet],
        ctaTitle: String,
        onContinue: @MainActor @escaping () -> Void
    ) {
        self.title = title
        self.bullets = bullets
        self.ctaTitle = ctaTitle
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.xl) {
                    Text(title)
                        .dodFont(DODType.displayLarge)
                        .foregroundStyle(DODColor.label)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: DODSpacing.lg) {
                        ForEach(bullets) { bullet in
                            row(for: bullet)
                        }
                    }
                }
                .padding(.horizontal, DODSpacing.xl)
                .padding(.top, DODSpacing.xl + DODSpacing.md)
                .padding(.bottom, DODSpacing.lg)
            }

            ctaButton
                .padding(.horizontal, DODSpacing.xl)
                .padding(.bottom, DODSpacing.lg)
                .padding(.top, DODSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DODColor.surface.ignoresSafeArea())
    }

    private func row(for bullet: Bullet) -> some View {
        HStack(alignment: .top, spacing: DODSpacing.md) {
            Image(systemName: bullet.systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(DODColor.accent)
                .frame(width: 44, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text(bullet.title)
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
                Text(bullet.caption)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bullet.title). \(bullet.caption)")
    }

    private var ctaButton: some View {
        Button(action: onContinue) {
            Text(ctaTitle)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DODSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                        .fill(DODColor.accent)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("DOD content") {
    OnboardingSheet(
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
                systemImage: "bookmark.fill",
                title: "Save your favorites",
                caption: "Tap the bookmark on any recipe to find it again later."
            ),
        ],
        ctaTitle: "Get cooking",
        onContinue: {}
    )
}
