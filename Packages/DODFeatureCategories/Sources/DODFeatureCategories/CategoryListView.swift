import DODDesignSystem
import DODDomain
import SwiftUI

/// All-categories list. Tapping a row notifies the host via `onSelect`.
///
/// Layout follows iOS-stock conventions per US-19 / CL-31..33:
/// `.insetGrouped` list style (system rounded card with native separators),
/// system disclosure indicators on each row. The name-filter search bar is
/// the shared `DODSearchField` (T-648 / CL-126 / REG-32) slotted into a
/// `VStack` above the List so this surface matches the Search-tab bar
/// visually — both render `DODColor.surfaceElevated` brand brown inside
/// a `Capsule(style: .continuous)` shape. The deliberate trade for
/// visual unity: the bar no longer slides into a nav-bar drawer the way
/// the pre-T-648 `.searchable` modifier did; it sits as a sticky element
/// above the List. No custom DesignSystem tokens are introduced; the row
/// composition uses only existing `DODType` / `DODColor` / `DODSpacing`
/// values per CL-31.
///
/// Surface color follows the post-T-520 `DODColor.surface` contract
/// (US-30 / CL-51): the scroll surround paints `DODColor.surface`
/// (`#F9F6EF` light / `#42210B` dark) via `.scrollContentBackground(.hidden)
/// + .background(DODColor.surface)` — the same pattern Feed / Saved /
/// Search use, so the Categories tab matches the rest of the app.
/// The `.insetGrouped` row cells keep their system-default fill
/// (`UIColor.secondarySystemGroupedBackground`) so row-text contrast
/// carries forward unchanged. T-430 / CL-44 previously applied a one-tab
/// `.background(DODColor.castIronBrown)` override here; T-560 / CL-54
/// reverted that override (swapping in `DODColor.surface`) after the
/// T-520 color overhaul re-tinted `surface` to the user's chosen
/// brand-warm palette across every screen.
public struct CategoryListView: View {

    @State private var viewModel: CategoryListViewModel
    @State private var searchText: String = ""
    public let onSelect: (DODDomain.Category) -> Void

    public init(
        viewModel: CategoryListViewModel,
        onSelect: @escaping (DODDomain.Category) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    public var body: some View {
        // T-781 / DUT-87 — no `.navigationTitle`; the "Categories" title and the
        // filter field scroll with the list (`DODScreenHeader` + `DODSearchField`
        // are the first list rows in `loadedList`), consistent with every tab.
        content
            .task { await viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DODColor.surface)
        case .error:
            EmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load categories",
                message: "Tap retry to try again.",
                action: .init(title: "Retry") {
                    Task { await viewModel.retry() }
                }
            )
        case .loaded:
            loadedList
        }
    }

    /// `.insetGrouped` list of categories with a `DODSearchField` name
    /// filter scoped to `category.name` (case-insensitive). When the
    /// typed query has no matches, an inline secondary-label row
    /// replaces the result rows so the search field itself remains
    /// visible (per AC-19.6).
    ///
    /// T-648 / CL-126 / REG-32: the pre-T-648 `.searchable(text:placement:
    /// .navigationBarDrawer(displayMode: .automatic))` modifier is
    /// replaced by the shared `DODSearchField` slotted into a
    /// `VStack(spacing: 0)` above the `List` so this bar matches the
    /// Search-tab bar visually (both render `DODColor.surfaceElevated`
    /// brand brown inside a `Capsule(style: .continuous)` shape). The
    /// `#if os(iOS)` guard remains for `.listStyle(.insetGrouped)`
    /// (iOS-only modifier); production runs are iOS-only, so the macOS
    /// branch only keeps `swift test` (which builds for the host
    /// platform) green.
    private var loadedList: some View {
        let filtered = CategoryListView.filtered(
            categories: viewModel.categories,
            matching: searchText
        )
        // T-781 / DUT-87 — title + filter scroll above the category card. The
        // `.insetGrouped` List was replaced with a ScrollView + a single brand
        // rounded card (`categoryCard`) so the header can scroll with the list
        // WITHOUT the List's section grouping squaring off the first cell's top
        // corners or adding its top inset. The filter's border + shadow now come
        // from `DODSearchField` itself, so it matches the Search tab's field.
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                DODScreenHeader("Categories")
                DODSearchField(text: $searchText, placeholder: "Search")
                    .padding(.horizontal, DODSpacing.md)
                    .padding(.bottom, DODSpacing.sm)
                    .accessibilityIdentifier("dod.search.field.categories")
                categoryCard(filtered)
                    .padding(.horizontal, DODSpacing.md)
                    .padding(.bottom, DODSpacing.md)
            }
        }
        .background(DODColor.surface)
    }

    /// The categories as one brand rounded card (`surfaceElevated`, rows split
    /// by hairline dividers) — reproduces the prior `.insetGrouped` grouping in
    /// a ScrollView so the title + filter can scroll above it (T-781 / DUT-87).
    /// The card clip rounds the first/last rows, fixing the squared-off first
    /// cell the List section grouping produced.
    @ViewBuilder
    private func categoryCard(_ filtered: [DODDomain.Category]) -> some View {
        VStack(spacing: 0) {
            if filtered.isEmpty {
                Text("No categories match '\(searchText)'")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DODSpacing.md)
                    .accessibilityIdentifier("category-empty-search")
            } else {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, category in
                    categoryRow(category)
                        .padding(.horizontal, DODSpacing.md)
                        .padding(.vertical, DODSpacing.sm)
                    if index < filtered.count - 1 {
                        Divider()
                            .overlay(DODColor.surfaceDivider)
                            .padding(.leading, DODSpacing.md)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
    }

    /// One row in the category card. Renders as an iOS-stock cell
    /// shape — category name on the leading side, recipe count + system
    /// disclosure chevron on the trailing side. The chevron uses the
    /// system `chevron.forward` glyph at `.footnote` weight with the
    /// `.tertiary` foreground style, matching what `NavigationLink` itself
    /// draws inside an `.insetGrouped` list. We don't use `NavigationLink`
    /// here because the host (`TabStack`) owns navigation via `onSelect`.
    private func categoryRow(_ category: DODDomain.Category) -> some View {
        Button {
            onSelect(category)
        } label: {
            HStack(spacing: DODSpacing.sm) {
                Text(category.name)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                Spacer(minLength: DODSpacing.xs)
                Text("\(category.count)")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .monospacedDigit()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name), \(category.count) recipes")
        .accessibilityAddTraits(.isButton)
    }

    /// Pure helper used by `loadedList` and exercised by L1 unit tests.
    /// Filters `categories` by `category.name` case-insensitively. Empty
    /// or whitespace-only `query` returns `categories` unchanged. Kept
    /// `internal` (not `private`) so the test target can exercise it
    /// without relying on `@testable import` of view internals.
    /// Spec trace: US-19 AC-19.3.
    static func filtered(
        categories: [DODDomain.Category],
        matching query: String
    ) -> [DODDomain.Category] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return categories }
        return categories.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
