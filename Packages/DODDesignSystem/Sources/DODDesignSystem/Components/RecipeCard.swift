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
        .clipShape(RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous))
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

    private var heroSection: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: heroImageURL) { phase in
                switch phase {
                case .empty:
                    LoadingSkeleton(cornerRadius: 0)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(DODColor.labelSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DODColor.surface)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 140)
            .clipped()
            .accessibilityHidden(true)

            if let totalTimeDisplay {
                timeChip(totalTimeDisplay)
                    .padding(DODSpacing.xs)
            }

            // T-774 / DUT-80 — "Downloaded" badge, bottom-leading so it never
            // collides with the top-trailing time chip at the Saved tab's
            // narrow half-width.
            if isDownloaded {
                Self.downloadedBadge
                    .padding(DODSpacing.xs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Self.titleText(title, highlightQuery: highlightQuery)
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .lineLimit(2)
            Text(excerpt)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.sm)
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
            Text(display)
        }
        .dodFont(DODType.caption)
        .foregroundStyle(DODColor.cream)
        .padding(.horizontal, DODSpacing.xxs)
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
        let base = totalTimeDisplay.map { "\(title). \(excerpt). \($0)." }
            ?? "\(title). \(excerpt)."
        return isDownloaded ? base + " Downloaded." : base
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
        self
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }

    /// Attach the state-aware long-press Save/Unsave context menu to a
    /// recipe card (US-34 / AC-34.1 / AC-34.6 / CL-103).
    ///
    /// The menu hosts a single `Button` whose `Label` branches on the
    /// supplied `isSaved` flag: a saved card surfaces "Unsave" with the
    /// outline `bookmark` glyph; an unsaved card surfaces "Save" with
    /// `bookmark.fill`. Tapping invokes `onToggle`, which the caller wires
    /// through `RecipeStore.toggleSaved(id:)` (the same seam used by the
    /// detail-screen nav-bar bookmark per AC-4.7 / AC-5.1; the store-side
    /// `toggleSaved` already flips in both directions, so tapping "Unsave"
    /// on a saved card correctly transitions the row to `isSaved == false`).
    ///
    /// **History.** CL-60 (T-590) originally shipped this helper as
    /// `recipeCardContextMenu(onSave:)` with always-"Save" + `bookmark.fill`
    /// regardless of state — the "no Unsave branch in v1" decision deferred
    /// the per-row `isSaved` plumbing on the basis that Feed/Categories/
    /// Search viewmodels don't carry a saved-IDs observation surface. CL-103
    /// (T-634) reverses that decision because the Saved tab is the high-
    /// value surface where `isSaved` is trivially `true` for every card
    /// (every card in `SavedView`'s grid is by definition saved), and
    /// long-pressing a saved card to see "Save" reads as broken even
    /// though the underlying toggle works. Feed/Categories/Search still
    /// pass `isSaved: false` with a TODO marker pending the CL-60
    /// path-(c) follow-up (viewmodel-owned saved-IDs sets hydrated on
    /// appear).
    ///
    /// The menu composes alongside `recipeCardTap` without eating the tap
    /// gesture (SwiftUI's `.contextMenu` is gesture-distinct from
    /// `.onTapGesture` — REG-DOD-LIST-SCROLL is unaffected).
    public func recipeCardContextMenu(
        isSaved: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        self.contextMenu {
            Button(action: onToggle) {
                Label(
                    isSaved ? "Unsave" : "Save",
                    systemImage: isSaved ? "bookmark" : "bookmark.fill"
                )
            }
        }
    }
}

// MARK: - List row variant (US-38 / AC-38.4 / CL-64, T-650)

extension RecipeCard {

    /// US-38 / AC-38.4 / CL-64.4 (T-650, 2026-05-27) — dense single-column
    /// row variant. Hosted alongside ``RecipeCard`` in the same file
    /// because it shares the time-chip body + the same `DODColor.surfaceElevated`
    /// background; lives as a nested struct so call sites read
    /// `RecipeCard.ListRow(...)` and the affinity to the gallery card is
    /// visible at the API surface.
    ///
    /// Layout (CL-64.4):
    ///   - 60×60pt `AsyncImage` thumbnail on the leading edge, clipped to
    ///     a `RoundedRectangle(cornerRadius: DODSpacing.xs)`.
    ///   - `VStack(.leading)` carrying the title (`.lineLimit(1)`,
    ///     `DODType.heading`) and the excerpt (`.lineLimit(1)`,
    ///     `DODType.caption`). The excerpt is single-line in the row
    ///     variant to keep the density (gallery card uses 2 lines).
    ///   - Optional time chip on the trailing edge — only rendered when
    ///     `totalTimeDisplay` is non-nil.
    ///   - `DODSpacing.sm` vertical padding around the row.
    ///   - `DODColor.surfaceElevated` background inside a
    ///     `RoundedRectangle(cornerRadius: DODSpacing.sm)` (matches the
    ///     gallery card's surface treatment).
    ///
    /// Composes with the same ``recipeCardTap(_:)`` +
    /// ``recipeCardContextMenu(isSaved:onToggle:)`` modifiers the gallery
    /// card uses, so the row's tap + long-press semantics are
    /// byte-identical (AC-34.1 / AC-34.6 preserved).
    public struct ListRow: View {

        public let title: String
        public let excerpt: String
        public let heroImageURL: URL?
        public let totalTimeDisplay: String?
        /// Active search query (DUT-10) — see ``RecipeCard/highlightQuery``.
        public let highlightQuery: String?

        public init(
            title: String,
            excerpt: String,
            heroImageURL: URL?,
            totalTimeDisplay: String? = nil,
            highlightQuery: String? = nil
        ) {
            self.title = title
            self.excerpt = excerpt
            self.heroImageURL = heroImageURL
            self.totalTimeDisplay = totalTimeDisplay
            self.highlightQuery = highlightQuery
        }

        public var body: some View {
            HStack(alignment: .center, spacing: DODSpacing.sm) {
                thumbnail
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    RecipeCard.titleText(title, highlightQuery: highlightQuery)
                        .dodFont(DODType.heading)
                        .foregroundStyle(DODColor.label)
                        .lineLimit(1)
                    Text(excerpt)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let totalTimeDisplay {
                    RecipeCard.timeChip(totalTimeDisplay)
                }
            }
            .padding(.horizontal, DODSpacing.sm)
            .padding(.vertical, DODSpacing.sm)
            .background(DODColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous))
        }

        /// 60×60pt leading thumbnail. AsyncImage states map to the same
        /// loading / failure visuals the gallery card uses, scaled down
        /// to the smaller frame. Hidden from accessibility — the parent
        /// row's `recipeCardTap` modifier collapses children into the
        /// row's combined label.
        private var thumbnail: some View {
            AsyncImage(url: heroImageURL) { phase in
                switch phase {
                case .empty:
                    LoadingSkeleton(cornerRadius: DODSpacing.xs)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo")
                        .foregroundStyle(DODColor.labelSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DODColor.surface)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: DODSpacing.xs, style: .continuous))
            .accessibilityHidden(true)
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
