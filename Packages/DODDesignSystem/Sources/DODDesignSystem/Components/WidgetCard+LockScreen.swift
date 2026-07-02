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
    /// A small `eyebrow` label ("LATEST RECIPE" / "LATEST ARTICLE") over the
    /// post `title`. DUT-451: the excerpt/description line was removed so the
    /// title gets the freed vertical space; DUT-452: the eyebrow is now a
    /// parameter so the Latest Article widget reuses this exact layout.
    public struct LockScreenContent: Equatable, Sendable {
        public let eyebrow: String
        public let title: String

        public init(eyebrow: String, title: String) {
            self.eyebrow = eyebrow
            self.title = title
        }
    }

    /// `.accessoryRectangular` layout (DUT-451): a small eyebrow over a
    /// multi-line title. No description line — the title takes the whole card
    /// so more of the post name shows. Rendered text-only; the system applies
    /// the monochrome tint pass at present-time so we paint nothing decorative.
    public struct LockScreenRectangular: View {

        public let content: LockScreenContent

        public init(content: LockScreenContent) {
            self.content = content
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 1) {
                Text(content.eyebrow)
                    // DUT-451 — smaller eyebrow (was .caption2) to free room.
                    .font(.system(size: 9, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .lineLimit(1)

                Text(content.title)
                    .font(.system(.headline, design: .default, weight: .semibold))
                    // DUT-451 — was 2 lines; the dropped excerpt frees a 3rd.
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
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

        let eyebrow: String
        let message: String

        /// Defaults match the latest-recipe surface; the Latest Article widget
        /// (DUT-452) passes its own eyebrow + message to reuse this face.
        public init(
            eyebrow: String = "Latest Recipe",
            message: String = "Open the app to see the latest recipe."
        ) {
            self.eyebrow = eyebrow
            self.message = message
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 1) {
                Text(eyebrow)
                    .font(.system(size: 9, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .lineLimit(1)

                Text("Dutch Oven Daddy")
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .lineLimit(1)

                Text(message)
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

        /// Saved-recipe count shown inside the bookmark (DUT-453). `nil`/0 →
        /// the plain bookmark shortcut (unchanged from DUT-77).
        public let count: Int?

        public init(count: Int? = nil) {
            self.count = count
        }

        public var body: some View {
            if let count, count > 0 {
                // DUT-453 — knock the count OUT of the filled bookmark so the
                // number reads as the accessory disc / wallpaper behind it. A
                // plain overlay would paint number + glyph in the same tint
                // color (invisible); `.destinationOut` + `compositingGroup`
                // carves it, surviving the monochrome tint pass.
                ZStack {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 38, weight: .semibold))
                    Text(Self.badge(count))
                        .font(.system(size: 15, weight: .heavy))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .blendMode(.destinationOut)
                        .offset(y: -3)  // bookmark's visual center sits above middle
                }
                .compositingGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        /// The count string that fits inside the glyph — caps at "99+".
        static func badge(_ count: Int) -> String {
            count > 99 ? "99+" : "\(count)"
        }
    }
}

#Preview("Lock Screen Rectangular — populated") {
    WidgetCard.LockScreenRectangular(
        content: .init(eyebrow: "Latest Recipe", title: "Garlic Butter Skillet Corn")
    )
    .frame(width: 172, height: 76)
}

#Preview("Lock Screen Rectangular — long title") {
    WidgetCard.LockScreenRectangular(
        content: .init(
            eyebrow: "Latest Recipe",
            title: "Slow-Roasted Bourbon Berry Cheesecake with Maple Glaze"
        )
    )
    .frame(width: 172, height: 76)
}

#Preview("Lock Screen Rectangular — article") {
    WidgetCard.LockScreenRectangular(
        content: .init(
            eyebrow: "Latest Article",
            title: "Seasoning Cast Iron: The Only Guide You Need"
        )
    )
    .frame(width: 172, height: 76)
}

#Preview("Lock Screen Rectangular — empty") {
    WidgetCard.LockScreenEmpty()
        .frame(width: 172, height: 76)
}

#Preview("Lock Screen Circular — Saved bookmark (count)") {
    WidgetCard.LockScreenCircularBookmark(count: 12)
        .frame(width: 76, height: 76)
}
