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

    public init(
        title: String,
        excerpt: String,
        heroImageURL: URL?,
        totalTimeDisplay: String? = nil
    ) {
        self.title = title
        self.excerpt = excerpt
        self.heroImageURL = heroImageURL
        self.totalTimeDisplay = totalTimeDisplay
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
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(title)
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

    private var accessibilityLabel: String {
        if let totalTimeDisplay {
            "\(title). \(excerpt). \(totalTimeDisplay)."
        } else {
            "\(title). \(excerpt)."
        }
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

    /// Attach the standard "Save" long-press context menu to a recipe card
    /// (US-34 / AC-34.1 / CL-59).
    ///
    /// The menu hosts a single `Button` with the `bookmark.fill` SF Symbol
    /// and the label "Save"; tapping it invokes `onSave`. Menu copy stays
    /// "Save" regardless of the recipe's current saved state — see CL-59
    /// for the "no Unsave branch in v1" rationale.
    ///
    /// The menu composes alongside `recipeCardTap` without eating the tap
    /// gesture (SwiftUI's `.contextMenu` is gesture-distinct from
    /// `.onTapGesture` — REG-DOD-LIST-SCROLL is unaffected).
    public func recipeCardContextMenu(onSave: @escaping () -> Void) -> some View {
        self.contextMenu {
            Button(action: onSave) {
                Label("Save", systemImage: "bookmark.fill")
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
    /// ``recipeCardContextMenu(onSave:)`` modifiers the gallery card uses,
    /// so the row's tap + long-press semantics are byte-identical
    /// (AC-34.1 preserved).
    public struct ListRow: View {

        public let title: String
        public let excerpt: String
        public let heroImageURL: URL?
        public let totalTimeDisplay: String?

        public init(
            title: String,
            excerpt: String,
            heroImageURL: URL?,
            totalTimeDisplay: String? = nil
        ) {
            self.title = title
            self.excerpt = excerpt
            self.heroImageURL = heroImageURL
            self.totalTimeDisplay = totalTimeDisplay
        }

        public var body: some View {
            HStack(alignment: .center, spacing: DODSpacing.sm) {
                thumbnail
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    Text(title)
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
