import DODDesignSystem
import DODDomain
import SwiftUI

/// Idle empty state shown before the user types. Surfaces their recent
/// queries (US-12 / AC-12.4) and top categories as one-tap suggestions
/// (US-12 / AC-12.4). When there are no recents and no categories yet —
/// e.g. truly first launch with no network — falls back to the legacy
/// "type at least 2 characters" prompt.
///
/// Extracted from `SearchView.swift` to `IdleSuggestionsView.swift` to
/// keep `SearchView.swift` under SwiftLint's 400-line cap. The split
/// landed incidentally during T-650 (the layout-toggle PR added enough
/// branching in `SearchView` to overrun the cap). Like the earlier
/// `FlowLayout` split, this helper has no logical dependency on the
/// rest of `SearchView.swift` — it's a self-contained subview consumed
/// by the `.idle` arm of `SearchView`'s `content` switch.
struct IdleSuggestionsView: View {
    let recents: [String]
    let topCategories: [DODDomain.Category]
    let onRecentTap: (String) -> Void
    let onCategoryTap: (DODDomain.Category) -> Void
    let onClearRecents: () -> Void
    /// US-33 / AC-33.3 / CL-57: per-term context-menu removal.
    let onRemoveRecent: (String) -> Void

    var body: some View {
        if recents.isEmpty && topCategories.isEmpty {
            EmptyState(
                systemImage: "magnifyingglass",
                title: "Find a recipe",
                message: "Type at least 2 characters to search."
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.lg) {
                    if !recents.isEmpty {
                        // US-29 / AC-29.2 / CL-49.2: the "Recent" section
                        // header is rendered with the title at the
                        // leading edge and a "Clear All" button at the
                        // trailing edge. The button wipes the
                        // `UserDefaults`-backed recent-searches store
                        // via `RecentSearches.clear()`.
                        recentsSection
                    }
                    if !topCategories.isEmpty {
                        section(title: "Try") {
                            FlowLayout(spacing: DODSpacing.xs) {
                                ForEach(topCategories) { category in
                                    pill(text: category.name, systemImage: "magnifyingglass") {
                                        onCategoryTap(category)
                                    }
                                    // T-638 / CL-107 — stable test handle for the
                                    // L5 E2E `test_search_latest_recipes_pill_returns_recent_branch`
                                    // (taps the matching pill → asserts the
                                    // result count lands in the 3...8 range,
                                    // discriminating against the failure mode
                                    // of a literal text search returning either
                                    // ~0 or many random matches — pins CL-106
                                    // part 3 + REG-21). Case-insensitive name
                                    // match mirrors the same check `SearchView`
                                    // uses to route the tap to
                                    // `surfaceLatestRecipes(...)`; the
                                    // `topCategorySuggestions` rank can drift
                                    // as recipe counts change so a per-pill
                                    // identifier on the matching one is the
                                    // robust hook.
                                    .accessibilityIdentifier(
                                        isLatestRecipesCategory(category)
                                            ? "dod.search.tryPill.latestRecipes" : ""
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(DODSpacing.md)
            }
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            HStack {
                Text("Recent")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
                Spacer()
                // US-33 / AC-33.1 / CL-57: orange matches gear icon.
                Button("Clear All", action: onClearRecents)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.accent)
                    .accessibilityLabel("Clear all recent searches")
            }
            FlowLayout(spacing: DODSpacing.xs) {
                ForEach(Array(recents.enumerated()), id: \.offset) { _, query in
                    pill(text: query, systemImage: "clock") {
                        onRecentTap(query)
                    }
                    // US-33 / AC-33.2 / CL-57: long-press → "Clear".
                    // US-33 / CL-105 (T-636): force `.tint(.red)` on the
                    // destructive button so the SF Symbol trash icon
                    // matches the red destructive title text. Without an
                    // explicit tint the symbol inherits the ancestral
                    // accent (`DODColor.accent` = orange, per CL-57's
                    // "Clear All" treatment), which left the icon orange
                    // while the label rendered red — visually mismatched.
                    .contextMenu {
                        Button(role: .destructive) {
                            onRemoveRecent(query)
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            Text(title)
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
            content()
        }
    }

    /// T-638 / CL-107 — case-insensitive name match (or id-1590 fallback)
    /// against the "Latest Recipes" WP category, mirroring the same check
    /// `SearchView` uses to route the tap to `surfaceLatestRecipes(...)`.
    /// Kept in sync with that call site by convention (CL-106's id `1590`
    /// + name-match contract).
    private func isLatestRecipesCategory(_ category: DODDomain.Category) -> Bool {
        category.id == 1590
            || category.name.localizedCaseInsensitiveCompare("Latest Recipes") == .orderedSame
    }

    private func pill(
        text: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DODSpacing.xxs) {
                Image(systemName: systemImage)
                Text(text).lineLimit(1)
            }
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.label)
            .padding(.horizontal, DODSpacing.sm)
            .padding(.vertical, DODSpacing.xs)
            .background(Capsule().fill(DODColor.surfaceElevated))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(text), suggestion")
    }
}
