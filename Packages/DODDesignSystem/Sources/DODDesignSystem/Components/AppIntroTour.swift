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
        /// Optional looping clip for the media area. When `nil` (the default),
        /// the slide falls back to the ``placeholderSymbol`` SF Symbol — so
        /// video and symbol slides can freely mix as real clips land per slide.
        public let video: IntroVideoSource?

        public init(
            id: Int,
            title: String,
            description: String,
            placeholderSymbol: String,
            video: IntroVideoSource? = nil
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.placeholderSymbol = placeholderSymbol
            self.video = video
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

    private var isFirst: Bool { Self.isFirst(index: index) }
    private var isLast: Bool { Self.isLast(index: index, pageCount: pages.count) }

    /// The "Previous" button is disabled (and — via DUT-564 — accessibility-hidden)
    /// on the first slide. Pulled out as a pure function so the end-slide nav-hiding
    /// contract is unit-testable without a ViewInspector dependency.
    static func isFirst(index: Int) -> Bool { index <= 0 }

    /// The "Next" button is disabled (and accessibility-hidden) on the last slide.
    static func isLast(index: Int, pageCount: Int) -> Bool { index >= pageCount - 1 }

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
            // DUT — cap the slide content to a centered reading column so the
            // `.fullScreenCover` tour doesn't stretch body text to an unreadable
            // measure (and fling the nav buttons to the far corners) on iPad. The
            // 500pt cap exceeds the widest iPhone content region, so compact /
            // iPhone stays byte-identical.
            .frame(maxWidth: 500)
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
                slide(page, offset: offset).tag(offset)
            }
        }
        // `.page` (PageTabViewStyle) is iOS-only — guard so DODDesignSystem still
        // compiles on the macOS L1 slice. Custom dots render the position below.
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
    }

    private func slide(_ page: Page, offset: Int) -> some View {
        VStack(spacing: DODSpacing.xl) {
            media(for: page, offset: offset)
            VStack(spacing: DODSpacing.sm) {
                Text(page.title)
                    .dodFont(DODType.displayLarge)
                    .foregroundStyle(DODColor.label)
                    .multilineTextAlignment(.center)
                    // DUT-694 (PR-C): let the headline grow vertically (like the
                    // body below) so it wraps instead of truncating first at
                    // large Dynamic Type sizes.
                    .fixedSize(horizontal: false, vertical: true)
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

    /// The slide's media area: a gapless looping clip when the page carries a
    /// ``Page/video`` (playing only while it's the current slide), otherwise the
    /// SF-symbol placeholder. Keeps video + symbol slides mixable (DUT-336).
    @ViewBuilder
    private func media(for page: Page, offset: Int) -> some View {
        if let video = page.video {
            LoopingVideoView(
                source: video,
                isActive: offset == index,
                posterSymbol: page.placeholderSymbol
            )
        } else {
            imagePlaceholder(page.placeholderSymbol)
        }
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
                // DUT: grow the hit region to the 44pt HIG minimum (the glyph is
                // only ~22pt tall). Frame the label content, not the button, so
                // the hidden end-slide button below (opacity 0 + a11y-hidden)
                // stays out of reach.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        // Keep the slot so the dots + CTA stay put; just hide it at the ends.
        .opacity(disabled ? 0 : 1)
        // DUT-564: a `.disabled` Button stays in the accessibility tree, so a
        // fully-transparent end-slide nav button gets read as "Previous/Next,
        // dimmed, button". Drop it from the a11y tree when it's hidden (mirrors
        // the placeholder's `.accessibilityHidden(true)` above).
        .accessibilityHidden(disabled)
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
