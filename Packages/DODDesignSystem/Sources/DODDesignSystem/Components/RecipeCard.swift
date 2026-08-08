import DODSupport
import SwiftUI

/// Reusable list row for recipes. Generic over content — takes primitive
/// inputs so DesignSystem stays decoupled from Domain types (plan §1).
/// Feature modules (Feed, Categories, Search, Saved) provide thin adapters
/// from their domain item to `RecipeCard`.
///
/// Spec trace: spec.md AC-1.3, AC-2.3, AC-3.3, AC-5.3.
public struct RecipeCard: View {

    public let title: String
    public let excerpt: String
    public let heroImageURL: URL?
    public let totalTimeDisplay: String?
    /// T-774 / DUT-80 — when true, a "Downloaded" badge overlays the hero.
    /// Default false (Feed/Categories/Search unchanged); only the Saved tab
    /// passes `true`, for recipes that are saved AND downloaded.
    public let isDownloaded: Bool
    /// Active search query (DUT-10). When non-nil/non-empty, its term matches in
    /// `title` are tinted in the brand accent; nil (every non-search host) keeps
    /// the plain `Text(title)` render byte-for-byte.
    public let highlightQuery: String?

    public init(
        title: String,
        excerpt: String,
        heroImageURL: URL?,
        totalTimeDisplay: String? = nil,
        highlightQuery: String? = nil,
        isDownloaded: Bool = false
    ) {
        self.title = title
        self.excerpt = excerpt
        self.heroImageURL = heroImageURL
        self.totalTimeDisplay = totalTimeDisplay
        self.highlightQuery = highlightQuery
        self.isDownloaded = isDownloaded
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroSection
            textSection
        }
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        // Note: we do NOT collapse children into a single accessibility element.
        // When a feature wraps RecipeCard in a Button, that Button derives its
        // accessibility label from the visible Text content — which gives
        // VoiceOver and XCUITest the right semantics (a tappable recipe row).
        // The accessibilityLabel computed property is still exposed for any
        // non-Button host that needs to apply it manually.
    }

    /// Composite label suitable for hosts that need to collapse the card into
    /// a single accessibility element (e.g. a custom-styled host without a
    /// Button wrapper).
    public var combinedAccessibilityLabel: String { accessibilityLabel }

    /// Hero photo + its corner overlays. The 140pt fixed-height crop keeps every
    /// gallery card a uniform size. The badges are alignment overlays so the time
    /// chip (top-trailing) never collides with the "Downloaded" badge
    /// (bottom-leading).
    private var heroSection: some View {
        heroImage
            .accessibilityHidden(true)
            .overlay(alignment: .topTrailing) {
                if let totalTimeDisplay {
                    timeChip(totalTimeDisplay)
                        .padding(DODSpacing.xs)
                }
            }
            .overlay(alignment: .bottomLeading) {
                // T-774 / DUT-80 — "Downloaded" badge, bottom-leading so it never
                // collides with the top-trailing time chip at the Saved tab's
                // narrow half-width.
                if isDownloaded {
                    Self.downloadedBadge
                        .padding(DODSpacing.xs)
                }
            }
    }

    private var textSection: some View {
        // T-839 (uniform card height) + T-845 (dynamic excerpt). A hidden sizer
        // pins the text block to a CONSTANT height — 2 title lines + 2 excerpt
        // lines at the current Dynamic Type — so every gallery card is the same
        // size (the `LazyVGrid` rows don't go ragged). The real content is
        // overlaid: the title takes its natural 1–2 lines (max 2 + "…"), and the
        // excerpt FILLS whatever height the title leaves via `ViewThatFits`, so a
        // short title shows more excerpt lines and a 2-line title shows 2 — with
        // the title↔excerpt padding (`DODSpacing.xs`) held constant. The list row
        // (`RecipeCard.ListRow`) renders its own text and is untouched.
        textBlockSizer
            .hidden()
            .overlay(alignment: .topLeading) { textBlockContent }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DODSpacing.sm)
    }

    /// Invisible spacer fixing the text block to "2-line title + 2-line excerpt"
    /// (the maximum), so the card height is constant. `reservesSpace` keeps it
    /// correct across Dynamic Type sizes with no hard-coded height.
    private var textBlockSizer: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(verbatim: " ")
                .dodFont(titleFont)
                .lineLimit(2, reservesSpace: true)
            Text(verbatim: " ")
                .dodFont(DODType.caption)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    /// Title (natural, max 2 lines) + an excerpt that fills the freed height:
    /// `ViewThatFits` picks the most lines (up to 4) that fit, so a 1-line title
    /// yields ~3 excerpt lines and a 2-line title yields 2 — each tail-truncated.
    private var textBlockContent: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Self.titleText(title, highlightQuery: highlightQuery)
                .dodFont(titleFont)
                .foregroundStyle(DODColor.label)
                .lineLimit(2)
                // Title claims its full natural height (up to 2 lines) FIRST;
                // without the priority the VStack compressed it to 1 line to give
                // the excerpt room, so a real 2-line title truncated early.
                .layoutPriority(1)
            ViewThatFits(in: .vertical) {
                excerptText.lineLimit(4)
                excerptText.lineLimit(3)
                excerptText.lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The excerpt run, shared across the `ViewThatFits` line-count variants.
    private var excerptText: some View {
        Text(excerpt)
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func timeChip(_ display: String) -> some View {
        Self.timeChip(display)
    }

    /// US-38 / AC-38.4 / CL-64.4 (T-650, 2026-05-27) — the trailing-edge
    /// time chip helper, promoted to a static so the `RecipeCard.ListRow`
    /// sibling can reuse the same visual treatment without copying the
    /// `Capsule` + `DODColor.castIronBrown.opacity(0.85)` body.
    static func timeChip(_ display: String) -> some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: "clock")
                .accessibilityHidden(true)  // DUT-693 — decorative glyph
            Text(display)
        }
        .dodFont(DODType.caption)
        .foregroundStyle(DODColor.cream)
        .padding(.horizontal, DODSpacing.xs)
        .padding(.vertical, DODSpacing.xxs)
        .background(
            Capsule().fill(DODColor.castIronBrown.opacity(0.85))
        )
    }

    /// T-774 / CL-171 (DUT-80) — the "Downloaded" status badge for the Saved
    /// tab. Mirrors ``timeChip(_:)``'s capsule but in the burnt-orange accent
    /// with a download glyph, so the two statuses read as distinct.
    static var downloadedBadge: some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: "arrow.down.circle.fill")
            Text("Downloaded")
        }
        .dodFont(DODType.caption)
        .foregroundStyle(DODColor.cream)
        .padding(.horizontal, DODSpacing.xs)
        .padding(.vertical, DODSpacing.xxs)
        .background(
            Capsule().fill(DODColor.burntOrange.opacity(0.9))
        )
    }

    private var accessibilityLabel: String {
        let time = totalTimeDisplay.map { " \($0)." } ?? ""
        let downloaded = isDownloaded ? " Downloaded." : ""
        return "\(title). \(excerpt).\(time)\(downloaded)"
    }

    // MARK: - Title highlighting (DUT-10)

    /// `Text` for a card title — plain when there's no active query (identical
    /// to the pre-DUT-10 `Text(title)`, so existing hosts + snapshots are
    /// untouched), or with `query` term matches tinted in the brand accent.
    /// Shared by the gallery card and ``ListRow``.
    static func titleText(_ title: String, highlightQuery: String?) -> Text {
        guard let highlightQuery, !highlightQuery.isEmpty else { return Text(title) }
        return Text(highlightedTitle(title, query: highlightQuery))
    }

    /// `title` as an `AttributedString` with every ``SearchTermHighlighter``
    /// match of `query` tinted in `DODColor.accent` (DUT-10). Pure + host-free
    /// so the highlight styling is unit-testable without a SwiftUI host.
    static func highlightedTitle(_ title: String, query: String) -> AttributedString {
        var attributed = AttributedString(title)
        for range in SearchTermHighlighter.matchedRanges(in: title, query: query) {
            let lower = attributed.index(attributed.startIndex, offsetByCharacters: range.lowerBound)
            let upper = attributed.index(attributed.startIndex, offsetByCharacters: range.upperBound)
            attributed[lower..<upper].foregroundColor = DODColor.accent
        }
        return attributed
    }
}

// MARK: - Tap modifier

extension View {
    /// Make a `RecipeCard` (or any recipe row) tappable as a navigation
    /// entry point WITHOUT eating the parent `ScrollView`'s vertical pan
    /// gesture.
    ///
    /// Why this exists (bug fix for DOD-LIST-SCROLL):
    /// The obvious idiom is `Button { onTap() } label: { RecipeCard(...) }
    /// .buttonStyle(.plain)`. Inside a `LazyVGrid` inside a `ScrollView`
    /// on iOS 26, the Button claims the cell's full rect as its tap
    /// gesture surface; when a single card is tall enough to dominate the
    /// viewport, the user's finger touch starts inside the Button and the
    /// scroll never gets a chance to win the gesture race. The screen
    /// appears stuck.
    ///
    /// Fix: use `.onTapGesture` (which doesn't compete with the
    /// surrounding scroll gesture) and apply the `.isButton`
    /// accessibility trait manually so VoiceOver + XCUITest still see
    /// the row as a tappable element.
    public func recipeCardTap(_ action: @escaping () -> Void) -> some View {
        // DUT-695 — trackpad/pointer lift on every recipe card (Feed/Saved/
        // Search/Categories all route through this modifier). `.hoverEffect` is
        // a no-op without a pointer, so iPhone is unaffected; it's unavailable on
        // macOS, where this package's L1 `swift test` compiles, so it's guarded.
        let tappable = self.contentShape(Rectangle())
        #if os(iOS)
        let hoverable = tappable.hoverEffect(.highlight)
        #else
        let hoverable = tappable
        #endif
        return
            hoverable
            .onTapGesture(perform: action)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }

    /// Attach the state-aware long-press Save/Unsave (+ Remove Download)
    /// context menu to a recipe card (US-34 / AC-34.1 / AC-34.6 / CL-103;
    /// the download branch is T-775 / DUT-81).
    ///
    /// The first `Button` branches on `isSaved`: a saved card surfaces
    /// "Unsave" + outline `bookmark`, an unsaved card "Save" + `bookmark.fill`.
    /// `onToggle` routes through `RecipeStore.toggleSaved(id:)`, which flips
    /// both directions, so "Unsave" on a saved card transitions to
    /// `isSaved == false`. When `isDownloaded` is true AND `onRemoveDownload`
    /// is supplied, a second "Remove Download" item (orange
    /// `square.and.arrow.down.badge.xmark`) appears beneath it —
    /// un-downloading the recipe without unsaving it.
    ///
    /// **History.** CL-60 (T-590) shipped always-"Save"; CL-103 (T-634) added
    /// the `isSaved` branch for the Saved tab (where every card is saved).
    /// Feed/Categories/Search still pass `isSaved: false` (and omit the
    /// download branch) pending the CL-60 path-(c) per-row state follow-up —
    /// so today only the Saved tab passes `isDownloaded`.
    ///
    /// Composes alongside `recipeCardTap` without eating the tap gesture
    /// (`.contextMenu` is gesture-distinct from `.onTapGesture`).
    ///
    /// **DUT-534 Part 2 — opt-in "Add to Shopping List".** When
    /// `onAddToShoppingList` is supplied, a third item (cart-plus glyph) appends
    /// the card's recipe ingredients to the Shopping List. It is opt-in so this
    /// shared helper (which serves Feed, Search, Categories, and Saved) only
    /// grows the item on the two surfaces that pass it (Feed + Search); the other
    /// two pass `nil`, so the item doesn't render and they're unaffected.
    public func recipeCardContextMenu(
        isSaved: Bool,
        isDownloaded: Bool = false,
        onToggle: @escaping () -> Void,
        onRemoveDownload: (() -> Void)? = nil,
        onAddToShoppingList: (() -> Void)? = nil
    ) -> some View {
        self.contextMenu {
            Button(action: onToggle) {
                Label(
                    isSaved ? "Unsave" : "Save",
                    systemImage: isSaved ? "bookmark" : "bookmark.fill"
                )
            }
            if isDownloaded, let onRemoveDownload {
                Button(action: onRemoveDownload) {
                    Label("Remove Download", systemImage: "square.and.arrow.down.badge.xmark")
                }
                .tint(DODColor.burntOrange)
            }
            if let onAddToShoppingList {
                Button(action: onAddToShoppingList) {
                    Label("Add to Shopping List", systemImage: "cart.badge.plus")
                }
                .accessibilityIdentifier("dod.card.addToShoppingList")
            }
        }
    }
}

#Preview("With time chip") {
    RecipeCard(
        title: "Garlic Butter Skillet Corn",
        excerpt: "An easy 15-minute side dish that pairs with everything.",
        heroImageURL: URL(string: "https://www.dutchovendaddy.com/wp-content/uploads/sample.jpg"),
        totalTimeDisplay: "15 min"
    )
    .padding(DODSpacing.md)
}

#Preview("No image") {
    RecipeCard(
        title: "Sourdough Bread",
        excerpt: "Crusty, chewy, slow-fermented.",
        heroImageURL: nil
    )
    .padding(DODSpacing.md)
}

#Preview("List row, with time chip") {
    RecipeCard.ListRow(
        title: "Garlic Butter Skillet Corn",
        excerpt: "An easy 15-minute side dish that pairs with everything.",
        heroImageURL: nil,
        totalTimeDisplay: "15 min"
    )
    .padding(DODSpacing.md)
}

#Preview("List row, no time chip") {
    RecipeCard.ListRow(
        title: "Sourdough Bread",
        excerpt: "Crusty, chewy, slow-fermented.",
        heroImageURL: nil
    )
    .padding(DODSpacing.md)
}
