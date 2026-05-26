import DODDesignSystem
import DODDomain
import SwiftUI

public struct SearchView: View {

    @State private var viewModel: SearchViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    public let onSelect: (RecipeListItem) -> Void

    public init(viewModel: SearchViewModel, onSelect: @escaping (RecipeListItem) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            FilterChipRow(
                filters: $viewModel.filters,
                categories: viewModel.availableCategories
            )
            content
        }
        .background(DODColor.surface)
        .navigationTitle("Search")
        .task { await viewModel.loadCategoriesIfNeeded() }
    }

    private var searchField: some View {
        HStack(spacing: DODSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DODColor.labelSecondary)
            TextField("Search recipes", text: $viewModel.query)
                .autocorrectionDisabled()
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DODColor.labelSecondary)
                }
                .accessibilityLabel("Clear")
            }
        }
        .padding(DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .padding(DODSpacing.md)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            IdleSuggestionsView(
                recents: viewModel.recentSearches,
                topCategories: viewModel.topCategorySuggestions,
                onRecentTap: { viewModel.selectRecent($0) },
                // US-29 / AC-29.1 / CL-49.1 + CL-49.5: tapping a "Try"
                // category pill populates the search field and runs a
                // normal text query through the existing debounce path.
                // The pre-T-500 path also set `filters.categoryID`, which
                // dropped every REST result whose recipe-detail page
                // hadn't yet hydrated the local category-IDs cache — the
                // smoking gun behind the "tag search returns no results"
                // round-6 report. CL-49 documents the full root cause.
                onCategoryTap: { category in
                    viewModel.query = category.name
                },
                onClearRecents: { viewModel.clearRecentSearches() }
            )
        case .searching:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .noResults:
            // US-29 / AC-29.3 / CL-49.3: glyph swap from
            // `questionmark.folder` to `questionmark.circle`. Explicitly
            // reverses AC-20.3's carve-out — round-6 user feedback was
            // that `questionmark.folder` reads as "in some folder I
            // haven't found" rather than "not found, period."
            // `questionmark.circle` is the iOS-stock "I can't find what
            // you asked for" glyph (Settings' search, Mail's search,
            // Notes' search all use it).
            EmptyState(
                systemImage: "questionmark.circle",
                title: "No recipes match '\(viewModel.query)'",
                message: "Try a different word or clear a filter."
            )
        case .offline:
            EmptyState(
                systemImage: "wifi.slash",
                title: "Search needs internet",
                message: "Reconnect to search dutchovendaddy.com."
            )
        case .results:
            ScrollView {
                LazyVGrid(
                    columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
                    spacing: DODSpacing.md
                ) {
                    ForEach(viewModel.items) { item in
                        RecipeCard(
                            title: item.title,
                            excerpt: item.excerpt,
                            heroImageURL: item.heroImage,
                            totalTimeDisplay: item.totalTimeDisplay
                        )
                        .recipeCardTap { onSelect(item) }
                    }
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.bottom, DODSpacing.lg)
            }
        }
    }
}

// MARK: - Filter chips

/// Horizontal row of filter chips above the results list. Each chip flips
/// one slice of `SearchFilters`; mutating the binding triggers
/// `SearchViewModel`'s `reapplyFilters` and the result set re-ranks
/// instantly without a network call (US-12 / AC-12.3).
struct FilterChipRow: View {
    @Binding var filters: SearchFilters
    let categories: [DODDomain.Category]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DODSpacing.xs) {
                categoryChip
                cookTimeChip
                recentlyViewedChip
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.bottom, DODSpacing.sm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search filters")
    }

    private var categoryChip: some View {
        Menu {
            // US-29 / AC-29.4 / CL-49.4: the "All categories" first row
            // is intentionally absent — the Categories tab (reachable
            // via bottom nav) is the canonical "browse all categories"
            // affordance. To clear a picked category here the user
            // re-taps the same category in the menu to deselect it.
            // The chip's display label still reads "All categories"
            // via `selectedCategoryName` when no category is picked.
            ForEach(categories) { category in
                Button(category.name) {
                    if filters.categoryID == category.id {
                        filters.categoryID = nil
                    } else {
                        filters.categoryID = category.id
                    }
                }
            }
        } label: {
            chipLabel(
                text: selectedCategoryName,
                systemImage: "tag.fill",
                isOn: filters.categoryID != nil
            )
        }
        .accessibilityLabel("Category filter, \(selectedCategoryName)")
    }

    private var cookTimeChip: some View {
        Menu {
            Button("Any time") { filters.cookTime = nil }
            ForEach(CookTimeBucket.allCases) { bucket in
                Button(bucket.label) { filters.cookTime = bucket }
            }
        } label: {
            chipLabel(
                text: filters.cookTime?.label ?? "Any time",
                systemImage: "clock",
                isOn: filters.cookTime != nil
            )
        }
        .accessibilityLabel("Cook time filter, \(filters.cookTime?.label ?? "any time")")
    }

    private var recentlyViewedChip: some View {
        Button {
            filters.recentlyViewedOnly.toggle()
        } label: {
            chipLabel(
                text: "Recently viewed",
                systemImage: "clock.arrow.circlepath",
                isOn: filters.recentlyViewedOnly
            )
        }
        .accessibilityLabel("Recently viewed only filter")
        .accessibilityAddTraits(filters.recentlyViewedOnly ? .isSelected : [])
    }

    private func chipLabel(text: String, systemImage: String, isOn: Bool) -> some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: systemImage)
            Text(text).lineLimit(1)
        }
        .dodFont(DODType.caption)
        .foregroundStyle(isOn ? DODColor.cream : DODColor.label)
        .padding(.horizontal, DODSpacing.sm)
        .padding(.vertical, DODSpacing.xxs)
        .background(
            Capsule().fill(isOn ? DODColor.castIronBrown : DODColor.surfaceElevated)
        )
    }

    private var selectedCategoryName: String {
        guard let id = filters.categoryID,
            let category = categories.first(where: { $0.id == id })
        else { return "All categories" }
        return category.name
    }
}

// MARK: - Idle suggestions

/// Idle empty state shown before the user types. Surfaces their recent
/// queries (US-12 / AC-12.4) and top categories as one-tap suggestions
/// (US-12 / AC-12.4). When there are no recents and no categories yet —
/// e.g. truly first launch with no network — falls back to the legacy
/// "type at least 2 characters" prompt.
struct IdleSuggestionsView: View {
    let recents: [String]
    let topCategories: [DODDomain.Category]
    let onRecentTap: (String) -> Void
    let onCategoryTap: (DODDomain.Category) -> Void
    let onClearRecents: () -> Void

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
                                    pill(text: category.name, systemImage: "tag.fill") {
                                        onCategoryTap(category)
                                    }
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
                Button("Clear All", action: onClearRecents)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.castIronBrown)
                    .accessibilityLabel("Clear all recent searches")
            }
            FlowLayout(spacing: DODSpacing.xs) {
                ForEach(Array(recents.enumerated()), id: \.offset) { _, query in
                    pill(text: query, systemImage: "clock") {
                        onRecentTap(query)
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

/// Hand-rolled flow layout — wraps subviews onto new rows when the proposal
/// runs out of width. Used for the chip rows in `IdleSuggestionsView`.
/// Kept private to DODFeatureSearch because it's a UX-quality helper, not
/// a general design-system component.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var posX = bounds.minX
        var posY = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if posX + size.width > bounds.maxX, posX > bounds.minX {
                posX = bounds.minX
                posY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: posX, y: posY),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            posX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
