import SwiftUI

/// The first-launch **App Intro**: a horizontally-paged, swipeable feature tour.
/// Built generic so the hosting app supplies the slide copy + a persistent CTA —
/// DesignSystem stays decoupled from product strings.
///
/// Spec trace: US-8 (amended by DUT-335 — the single-screen `OnboardingSheet` is
/// replaced by this paged tour). Each slide reserves space for a real app
/// screenshot (wired in later); for now that space shows an SF Symbol placeholder.
public struct AppIntroTour: View {

    /// One slide of the tour. `placeholderSymbol` is the SF Symbol shown in the
    /// reserved image area until real app screenshots are added (DUT-335).
    public struct Page: Identifiable, Sendable {
        public let id: Int
        /// Title Case headline.
        public let title: String
        /// Short, informative blurb (a sentence or two — not a wall of text).
        public let description: String
        public let placeholderSymbol: String

        public init(id: Int, title: String, description: String, placeholderSymbol: String) {
            self.id = id
            self.title = title
            self.description = description
            self.placeholderSymbol = placeholderSymbol
        }
    }

    public let pages: [Page]
    /// The persistent finish/skip button label, e.g. "Let's Get Cooking".
    public let ctaTitle: String
    public let onFinish: @MainActor () -> Void

    @State private var index = 0

    public init(
        pages: [Page],
        ctaTitle: String,
        onFinish: @MainActor @escaping () -> Void
    ) {
        self.pages = pages
        self.ctaTitle = ctaTitle
        self.onFinish = onFinish
    }

    private var isFirst: Bool { index <= 0 }
    private var isLast: Bool { index >= pages.count - 1 }

    public var body: some View {
        if pages.isEmpty {
            // DUT-347: no slides → nothing to tour; finish immediately rather than
            // showing a lone CTA over a blank screen.
            Color.clear.onAppear { onFinish() }
        } else {
            VStack(spacing: DODSpacing.lg) {
                pager
                pageDots
                navRow
                ctaButton
            }
            .padding(.bottom, DODSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DODColor.surface.ignoresSafeArea())
        }
    }

    // MARK: - Paged slides

    private var pager: some View {
        TabView(selection: $index) {
            // DUT-347: key by offset (matching `.tag(offset)` + the dots' index)
            // so selection / dots / "current page" stay consistent even if a
            // caller ever supplies non-contiguous Page ids.
            ForEach(Array(pages.enumerated()), id: \.offset) { offset, page in
                slide(page).tag(offset)
            }
        }
        // `.page` (PageTabViewStyle) is iOS-only — guard so DODDesignSystem still
        // compiles on the macOS L1 slice. Custom dots render the position below.
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
    }

    private func slide(_ page: Page) -> some View {
        VStack(spacing: DODSpacing.xl) {
            imagePlaceholder(page.placeholderSymbol)
            VStack(spacing: DODSpacing.sm) {
                Text(page.title)
                    .dodFont(DODType.displayLarge)
                    .foregroundStyle(DODColor.label)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(page.description)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, DODSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    /// Reserved image area — a placeholder until real screenshots land (DUT-335).
    /// Portrait, phone-screenshot-ish, so the eventual image drops straight in.
    private func imagePlaceholder(_ symbol: String) -> some View {
        RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
            .fill(DODColor.surfaceElevated)
            .aspectRatio(0.62, contentMode: .fit)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(DODColor.accent)
            )
            .frame(maxWidth: 260)
            .accessibilityHidden(true)
    }

    // MARK: - Controls

    private var pageDots: some View {
        HStack(spacing: DODSpacing.xs) {
            ForEach(pages.indices, id: \.self) { dot in
                Circle()
                    .fill(dot == index ? DODColor.accent : DODColor.labelSecondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        // DUT-344: expose page position to VoiceOver. The system page indicator is
        // suppressed (`.never`) in favor of these custom dots, so without this a
        // VoiceOver user gets no "page N of M" feedback on the first-launch tour.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(index + 1) of \(pages.count)")
    }

    private var navRow: some View {
        HStack {
            navButton("Previous", disabled: isFirst) {
                withAnimation { index = max(0, index - 1) }
            }
            .accessibilityIdentifier("app-intro-previous")
            Spacer()
            navButton("Next", disabled: isLast) {
                withAnimation { index = min(pages.count - 1, index + 1) }
            }
            .accessibilityIdentifier("app-intro-next")
        }
        .padding(.horizontal, DODSpacing.xl)
    }

    private func navButton(
        _ title: String,
        disabled: Bool,
        action: @MainActor @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.accent)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        // Keep the slot so the dots + CTA stay put; just hide it at the ends.
        .opacity(disabled ? 0 : 1)
    }

    private var ctaButton: some View {
        Button(action: onFinish) {
            Text(ctaTitle)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DODSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                        .fill(DODColor.accent)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DODSpacing.xl)
        .accessibilityIdentifier("app-intro-cta")
    }
}

#Preview("App Intro") {
    AppIntroTour(
        pages: [
            .init(
                id: 0,
                title: "Welcome to Dutch Oven Daddy",
                description: "Your guide from first cookout to cast iron hero.",
                placeholderSymbol: "flame.fill"
            ),
            .init(
                id: 1,
                title: "Cook Mode",
                description: "Cook one step at a time, with each step read aloud.",
                placeholderSymbol: "speaker.wave.2.fill"
            ),
        ],
        ctaTitle: "Let's Get Cooking",
        onFinish: {}
    )
}
