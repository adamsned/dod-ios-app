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

        /// Standard-mode look (DUT-1384): the recipe/article name centred over
        /// the hero photo, the orange "Latest Article / Latest Recipe" eyebrow
        /// in the top-left corner, and (recipes only) the cook-time badge in the
        /// opposite, bottom-right corner. A gradient darkens the top edge (for
        /// the eyebrow) and the lower half (for the title) so both read on any
        /// photo. The hero sits in a `Color.clear` overlay so a non-square photo
        /// can never grow the card. Tinted/Vibrant keeps the container-anchored
        /// title in ``RenderingModeAwareSmall`` (DUT-9).
        @ViewBuilder
        static func overlayLayout(content: Content) -> some View {
            ZStack {
                Color.clear
                    .overlay { Hero(url: content.heroImageURL) }
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.65), location: 0),
                        .init(color: .black.opacity(0.25), location: 0.35),
                        .init(color: .black.opacity(0.55), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Text(content.title)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DODSpacing.sm)
                    // Keeps the centred title clear of the corner eyebrow + badge.
                    .padding(.vertical, DODSpacing.lg + DODSpacing.xxs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text(content.eyebrow)
                            .font(.system(.caption2, design: .default, weight: .semibold))
                            .foregroundStyle(DODColor.burntOrange)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                    if let totalTime = content.totalTimeDisplay {
                        HStack {
                            Spacer(minLength: 0)
                            TimeChip(text: totalTime)
                        }
                    }
                }
                .padding(DODSpacing.sm)
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
                        // DUT-1381 — the title wins its space over the greedy
                        // hero and may take 3 lines / scale, so a long name
                        // isn't clipped at 2 lines (matches the Standard path).
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DODSpacing.sm)
                        .layoutPriority(1)
                        .widgetAccentable()
                }
            }
        }
    }
    #endif
}
