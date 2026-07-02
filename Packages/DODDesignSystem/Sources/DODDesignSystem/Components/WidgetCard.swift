import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

/// Visual components used by the home-screen widget (spec.md US-9). Defined
/// in DODDesignSystem so they can be snapshot-tested via the existing
/// SnapshotTesting harness (constitution §6 L4). The widget extension hosts
/// these inside its `TimelineEntryView`; the only WidgetKit dependency in
/// this module is the iOS-only ``Image.widgetAccentedRenderingMode(_:)``
/// modifier used inside ``WidgetCard/Hero`` to opt the real recipe photo out
/// of the iOS 18+ "Tinted" / "Vibrant" home-screen desaturation pass (spec
/// US-23 / AC-23.2). The modifier lives on `SwiftUICore.Image` not
/// `SwiftUICore.View`, so applying it at the entry-view layer would require
/// breaking apart the ``Small``/``Medium`` API — surgically applying it
/// inside ``Hero`` is the bounded fix. WidgetKit is iOS-only and the import
/// is `#if canImport(WidgetKit)`-gated so the macOS test slice
/// (`swift test`) continues to build.
///
/// All variants accept a single ``WidgetCard.Content`` struct so the call
/// site is identical to the production code path.
public enum WidgetCard {

    /// Plain-old-data input for the widget card variants. Mirrors the
    /// subset of `WidgetSnapshot.Entry` (DODSupport) that the views render.
    public struct Content: Equatable, Sendable {
        public let title: String
        public let excerpt: String
        public let heroImageURL: URL?
        public let totalTimeDisplay: String?
        /// DUT-460 — the adaptive eyebrow ("Latest Recipe" / "Latest Article"),
        /// replacing the old hardcoded "New on DOD". Defaults to "Latest Recipe"
        /// so existing call sites (previews / tests) stay source-compatible.
        public let eyebrow: String

        public init(
            title: String,
            excerpt: String,
            heroImageURL: URL? = nil,
            totalTimeDisplay: String? = nil,
            eyebrow: String = "Latest Recipe"
        ) {
            self.title = title
            self.excerpt = excerpt
            self.heroImageURL = heroImageURL
            self.totalTimeDisplay = totalTimeDisplay
            self.eyebrow = eyebrow
        }
    }

    // MARK: - Small

    /// Square small-widget layout: hero behind a bottom gradient + title.
    public struct Small: View {

        public let content: Content

        public init(content: Content) {
            self.content = content
        }

        public var body: some View {
            ZStack(alignment: .bottomLeading) {
                Hero(url: content.heroImageURL)

                // Contrast scrim behind the title. See ``TintSafeScrim`` for
                // why this is a `.fullColor` rasterised `Image` and not a
                // plain translucent `LinearGradient` (DUT-9 root cause).
                TintSafeScrim()

                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    if let totalTime = content.totalTimeDisplay {
                        TimeChip(text: totalTime)
                    }
                    Text(content.title)
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(DODSpacing.sm)
            }
        }
    }

    // MARK: - Medium

    /// Wide medium-widget layout: hero on the left, copy on the right.
    public struct Medium: View {

        public let content: Content

        public init(content: Content) {
            self.content = content
        }

        public var body: some View {
            HStack(spacing: 0) {
                Hero(url: content.heroImageURL)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: DODSpacing.xs) {
                    Text(content.eyebrow)  // DUT-460 — was "New on DOD"
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .foregroundStyle(DODColor.burntOrange)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(content.title)
                        .font(.system(.headline, design: .default, weight: .semibold))
                        .foregroundStyle(DODColor.label)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    if !content.excerpt.isEmpty {
                        Text(content.excerpt)
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(DODColor.labelSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if let totalTime = content.totalTimeDisplay {
                        Spacer(minLength: 0)
                        TimeChip(text: totalTime)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(DODSpacing.md)
                .frame(maxWidth: .infinity)
                // T-767 / CL-164 (DUT-73) — no inner background: the widget's
                // `containerBackground(for: .widget)` owns it, so Tinted/Clear
                // mode tints it (Apple News pattern) instead of the system
                // flattening a solid inner fill into a tint silhouette.
            }
        }
    }

    // MARK: - Placeholder

    /// AC-9.4: shown when no snapshot exists (first launch, App Group
    /// missing, version mismatch).
    public struct Placeholder: View {

        public init() {}

        public var body: some View {
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DODColor.burntOrange)
                Text("Dutch Oven Daddy")
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .foregroundStyle(DODColor.label)
                Text("Open the app to see today's featured recipe here.")
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(DODColor.labelSecondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DODSpacing.md)
            // T-767 / CL-164 — background owned by `containerBackground` (Tinted-safe).
        }
    }

    // MARK: - Shared primitives

    /// Hero image / fallback gradient.
    /// `internal` so saved-variant rows declared in
    /// `WidgetCard+Saved.swift` can reuse the same primitive.
    ///
    /// **Why synchronous load for `file://` URLs (T-391/T-392 follow-up):**
    /// `AsyncImage` is built on `URLSession` and does not reliably load
    /// `file://` URLs inside a widget extension process — the request
    /// completes with `.empty` rather than reading the local bytes. The
    /// `WidgetImageBridge` writes hero JPEGs into the App Group container
    /// (spec.md AC-21.2); reading them at render time is a trivially fast
    /// local file read (single-digit ms for a 100KB JPEG on the user's
    /// device), so we read synchronously via `UIImage(contentsOfFile:)` and
    /// pass the decoded `Image` directly. WidgetKit caches the rendered
    /// timeline entry image, so this happens once per timeline reload —
    /// roughly every 4 hours per the app's reload cadence. Falls back to
    /// `AsyncImage` for network URLs so unit-test fixtures and any future
    /// remote URL caller still works.
    ///
    /// The loaded ``image`` is opted out of the iOS 18+ home-screen
    /// "Tinted" / "Vibrant" desaturation pass via
    /// ``Image/widgetAccentedRenderingMode(_:)`` set to
    /// ``WidgetAccentedRenderingMode/fullColor`` — the recipe hero photo
    /// is the recognizable element of the widget, and a tinted
    /// monochromatic blur of a Dutch oven recipe is harder to identify
    /// at home-screen distance than the true-color photo. Apple's
    /// Photos / Music widgets use the same `.fullColor` opt-out on
    /// their photo / album-art content. The fallback gradient + glyph
    /// (shown while the image is loading or absent) intentionally
    /// **does not** opt out — it SHOULD tint with the system so the
    /// empty/loading state blends with the user's wallpaper choice
    /// rather than fighting it.
    /// Spec trace: spec.md US-23 / AC-23.2 /
    /// `widget-appearance-audit.md`.
    struct Hero: View {

        let url: URL?

        var body: some View {
            Group {
                if let url {
                    if url.isFileURL {
                        // Local App Group file — read synchronously. See
                        // doc-comment above for why AsyncImage can't be
                        // used for file:// URLs in widget extensions.
                        if let image = Self.loadLocalImage(at: url) {
                            loadedImage(image)
                        } else {
                            fallbackGradient
                        }
                    } else {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                loadedImage(image)
                            case .empty, .failure:
                                fallbackGradient
                            @unknown default:
                                fallbackGradient
                            }
                        }
                    }
                } else {
                    fallbackGradient
                }
            }
            .clipped()
        }

        /// Read a `file://` URL synchronously and wrap as a SwiftUI `Image`.
        /// Returns nil if the file doesn't exist or isn't a decodable
        /// image — caller renders the gradient placeholder, matching the
        /// AC-21.3 "graceful fallback when bytes absent" contract.
        ///
        /// `UIImage(contentsOfFile:)` is fully synchronous and uses
        /// ImageIO under the hood, which is what `AsyncImage` would call
        /// anyway after its (broken-in-widget-extensions) `URLSession`
        /// step. Reading a ~100KB JPEG on-device takes single-digit
        /// milliseconds — well under WidgetKit's timeline-build budget.
        ///
        /// `UIKit`-gated so the macOS `swift test` slice still builds
        /// (DODDesignSystem supports macOS 14+ for the non-visual tests).
        static func loadLocalImage(at url: URL) -> Image? {
            #if canImport(UIKit)
            guard let uiImage = UIImage(contentsOfFile: url.path) else {
                return nil
            }
            return Image(uiImage: uiImage)
            #else
            return nil
            #endif
        }

        /// Loaded recipe-photo branch. Extracted so the iOS 18+ /
        /// macOS 15+ ``Image/widgetAccentedRenderingMode(_:)`` opt-out
        /// can wrap the photo without polluting the `AsyncImage.phase`
        /// switch. The modifier lives on `Image` not `View`, so the
        /// call order is `image.resizable() -> Image` then
        /// `.widgetAccentedRenderingMode(.fullColor) -> some View`
        /// then the View-flavored `.aspectRatio(_:contentMode:)`. The
        /// pre-iOS-18 fallback path returns the same shape without the
        /// rendering-mode hint (a no-op on hosts where the
        /// Tinted/Vibrant appearances don't exist). The `macOS 15.0`
        /// floor in the `#available` check is what the modifier's
        /// own Apple-side availability annotation requires; the
        /// DODDesignSystem package supports macOS 14+ for the
        /// non-visual `swift test` slice, so the fallback path is
        /// required for the macOS 14 → 14.x compile target.
        private func loadedImage(_ image: Image) -> some View {
            #if canImport(WidgetKit)
            if #available(iOS 18.0, macOS 15.0, *) {
                return AnyView(
                    image
                        .resizable()
                        .widgetAccentedRenderingMode(.fullColor)
                        .aspectRatio(contentMode: .fill)
                )
            } else {
                return AnyView(image.resizable().aspectRatio(contentMode: .fill))
            }
            #else
            return AnyView(image.resizable().aspectRatio(contentMode: .fill))
            #endif
        }

        private var fallbackGradient: some View {
            LinearGradient(
                colors: [DODColor.burntOrange.opacity(0.85), DODColor.castIronBrown],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: "fork.knife")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))
            )
        }
    }

    /// Pill chip echoing the in-app RecipeCard look.
    struct TimeChip: View {

        let text: String

        #if canImport(WidgetKit)
        @Environment(\.widgetRenderingMode) private var widgetRenderingMode
        #endif

        /// DUT-479 — in `.accented` (Tinted/Clear) the system flattens a FILLED
        /// capsule into a solid tint blob, and the cream text tints to match it
        /// (→ invisible). So in accented mode we drop the fill for an OUTLINED
        /// capsule + tint-adaptive text (both take the wallpaper tint while the
        /// interior stays clear → legible), matching how the rest of the widget
        /// content stays legible in Tinted mode (DUT-73 / DUT-9). `.fullColor`
        /// keeps the cream-on-brown pill.
        private var isAccented: Bool {
            #if canImport(WidgetKit)
            return widgetRenderingMode == .accented
            #else
            return false
            #endif
        }

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text(text)
            }
            .font(.system(.caption2, design: .default, weight: .semibold))
            .foregroundStyle(isAccented ? DODColor.label : DODColor.cream)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                if isAccented {
                    Capsule().strokeBorder(DODColor.label.opacity(0.55), lineWidth: 1)
                } else {
                    Capsule().fill(DODColor.castIronBrown.opacity(0.92))
                }
            }
        }
    }
}

#Preview("Small") {
    WidgetCard.Small(
        content: .init(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
    )
    .frame(width: 158, height: 158)
}

#Preview("Medium") {
    WidgetCard.Medium(
        content: .init(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
    )
    .frame(width: 338, height: 158)
}

#Preview("Placeholder") {
    WidgetCard.Placeholder()
        .frame(width: 158, height: 158)
}
