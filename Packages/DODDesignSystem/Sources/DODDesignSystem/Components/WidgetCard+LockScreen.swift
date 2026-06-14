import SwiftUI

// Lock-screen-widget variants of ``WidgetCard``. Lives in its own file
// alongside the featured-widget primitives in `WidgetCard.swift` and the
// saved-recipes variants in `WidgetCard+Saved.swift` so the type stays
// under SwiftLint's 250-line cap.
//
// Lock-screen widgets render text-only, monochrome — the system tints
// the rendered glyphs and text against the user's Lock Screen wallpaper
// at present-time (`.accessoryRectangular` is the only family in scope
// per CL-37; circular / inline are explicitly out). No image rendering,
// no chips, no `Hero` primitive — those belong to the home-screen
// widget variants and would not survive the monochrome rendering pass.
//
// Tap targets are wired by the entry view via `widgetURL(_:)`:
// populated → `dod://recipe/<id>`, empty → `dod://feed`. No new parser
// grammar — both URLs are already covered by US-9's
// `WidgetDeepLinkParser`.
//
// Spec trace: spec.md US-22, AC-22.2 (text-only), AC-22.5 (L4 coverage
// in `LockScreenWidgetSnapshotTests`).
extension WidgetCard {

    /// Plain-old-data input for the lock-screen rectangular variant.
    /// Mirrors the *subset* of ``WidgetSnapshot.Entry`` (DODSupport) the
    /// rectangular surface needs — just title + excerpt. We deliberately
    /// drop `heroImageURL` / `totalTimeDisplay` here so callers can't
    /// accidentally try to render an image in a monochrome surface.
    public struct LockScreenContent: Equatable, Sendable {
        public let title: String
        public let excerpt: String

        public init(title: String, excerpt: String) {
            self.title = title
            self.excerpt = excerpt
        }
    }

    /// `.accessoryRectangular` layout: two-line title over a one-line
    /// excerpt. Rendered text-only — the system applies the monochrome
    /// tint pass at present-time so we paint nothing decorative.
    public struct LockScreenRectangular: View {

        public let content: LockScreenContent

        public init(content: LockScreenContent) {
            self.content = content
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text("Latest Recipe")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .lineLimit(1)

                Text(content.title)
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !content.excerpt.isEmpty {
                    Text(content.excerpt)
                        .font(.system(.caption, design: .default))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// AC-22.4 / CL-37: shown when no snapshot exists (first launch,
    /// App Group missing in a non-provisioned build, version mismatch).
    /// Distinct from the home-screen ``Placeholder`` so the copy can
    /// name the latest-recipe surface and the caller can wire the tap
    /// target to `dod://feed` (matching the home-screen widget's empty
    /// state per AC-9.4).
    public struct LockScreenEmpty: View {

        public init() {}

        public var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text("Latest Recipe")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .lineLimit(1)

                Text("Dutch Oven Daddy")
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .lineLimit(1)

                Text("Open the app to see the latest recipe.")
                    .font(.system(.caption, design: .default))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// `.accessoryCircular` "Saved" shortcut: a single `bookmark.fill` glyph
    /// (T-771 / CL-168 / DUT-77). Unlike the rectangular latest-recipe face
    /// this carries no per-recipe data — it's a static shortcut whose tap
    /// opens the Saved tab (`dod://saved`, wired by the entry view's
    /// `widgetURL`). CL-37 deferred `.accessoryCircular` for the *recipe*
    /// because there was no good single-glyph recipe payload; a bookmark
    /// shortcut IS that good payload. The glyph stays WidgetKit-free here so
    /// it remains L4-snapshot-testable (constitution §6); the entry view adds
    /// the `AccessoryWidgetBackground` disc + `.widgetAccentable()` tint pass.
    public struct LockScreenCircularBookmark: View {

        public init() {}

        public var body: some View {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 24, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("Lock Screen Rectangular — populated") {
    WidgetCard.LockScreenRectangular(
        content: .init(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything."
        )
    )
    .frame(width: 172, height: 76)
}

#Preview("Lock Screen Rectangular — long title") {
    WidgetCard.LockScreenRectangular(
        content: .init(
            title: "Slow-Roasted Bourbon Berry Cheesecake with Maple Glaze",
            excerpt: "A weekend project worth every minute in the oven."
        )
    )
    .frame(width: 172, height: 76)
}

#Preview("Lock Screen Rectangular — empty") {
    WidgetCard.LockScreenEmpty()
        .frame(width: 172, height: 76)
}

#Preview("Lock Screen Circular — Saved bookmark") {
    WidgetCard.LockScreenCircularBookmark()
        .frame(width: 76, height: 76)
}
