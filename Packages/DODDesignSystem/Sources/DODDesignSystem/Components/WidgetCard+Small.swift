import SwiftUI

#if canImport(WidgetKit)
import WidgetKit
#endif

// Square small-widget layout, split out of `WidgetCard.swift` to keep that
// file under the 400-line cap (matches the `+Large` / `+Saved` split).
extension WidgetCard {

    // MARK: - Small

    /// Square small-widget layout: hero behind a bottom gradient + title.
    ///
    /// **DUT-9 (4th attempt) — why this is now rendering-mode-adaptive.**
    /// Attempts 1–3 all kept the title *over the photo* and tried to protect
    /// it with a darkening scrim (plain gradient → `.fullColor` group →
    /// rasterised `.fullColor` `Image`). None can work in Tinted/Clear mode:
    /// in `.accented`/`.vibrant` the system re-colours the title with the
    /// *user's* chosen home-screen tint, so a dark tint makes the title
    /// dark-on-dark no matter how dark the scrim is. Contrast is simply not
    /// ours to control once text sits in the default group over a photo. The
    /// ``Medium`` and ``Large`` cards never had this bug because they put the
    /// title on the *container* background, where the system guarantees
    /// accent-vs-background contrast. So in Tinted/Vibrant mode we now do the
    /// same: photo on top, title on the container below (marked
    /// ``SwiftUI/View/widgetAccentable()`` so it lands in the accent group).
    /// Standard (`.fullColor`) mode keeps the original photo-overlay look.
    public struct Small: View {

        public let content: Content

        public init(content: Content) {
            self.content = content
        }

        public var body: some View {
            #if canImport(WidgetKit)
            RenderingModeAwareSmall(content: content)
            #else
            Self.overlayLayout(content: content)
            #endif
        }

        /// Standard-mode look: the recipe/article name centred over the hero
        /// photo (widget layout parity — no bottom rectangle band). A full-card
        /// gradient scrim darkens the whole photo just enough for the centred
        /// title to read on any image. Legible because `.fullColor` shows the
        /// real photo; the Tinted/Vibrant path (``RenderingModeAwareSmall``)
        /// still anchors the title on the container where contrast is
        /// guaranteed (DUT-9).
        @ViewBuilder
        static func overlayLayout(content: Content) -> some View {
            ZStack {
                Hero(url: content.heroImageURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                LinearGradient(
                    colors: [.black.opacity(0.25), .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Text(content.title)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                    .padding(DODSpacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    #if canImport(WidgetKit)
    /// Picks the ``Small`` layout by home-screen rendering mode (DUT-9): the
    /// photo-overlay look in Standard (`.fullColor`), and a container-anchored
    /// title in Tinted/Vibrant (`.accented`/`.vibrant`) where text-over-photo
    /// contrast can't be guaranteed. WidgetKit-gated so the macOS test slice
    /// still builds; on macOS ``Small`` uses the overlay layout directly.
    struct RenderingModeAwareSmall: View {

        @Environment(\.widgetRenderingMode) private var renderingMode

        let content: Content

        var body: some View {
            if renderingMode == .fullColor {
                Small.overlayLayout(content: content)
            } else {
                // Tinted/Vibrant: title on the container (not over the photo)
                // so the system's accent-vs-background contrast guarantee
                // applies — the technique that keeps ``Medium``/``Large``
                // legible. `.widgetAccentable()` puts the title in the accent
                // group; no inner background (the widget's `containerBackground`
                // owns it and the system tints it, T-767 / DUT-73 pattern).
                VStack(alignment: .leading, spacing: 0) {
                    Hero(url: content.heroImageURL)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Text(content.title)
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(DODColor.label)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DODSpacing.sm)
                        .widgetAccentable()
                }
            }
        }
    }
    #endif
}
