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
        content
            .navigationTitle("Categories")
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
        let baseList = List {
            if filtered.isEmpty {
                Text("No categories match '\(searchText)'")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .accessibilityIdentifier("category-empty-search")
                    // T-647 / CL-125 — brand brown surface (matches Recipes
                    // & Articles cards + the post-T-647 Settings cells)
                    // instead of the system default near-black row bg.
                    .listRowBackground(DODColor.surfaceElevated)
            } else {
                ForEach(filtered) { category in
                    categoryRow(category)
                        .listRowBackground(DODColor.surfaceElevated)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DODColor.surface)

        return VStack(spacing: 0) {
            DODSearchField(text: $searchText, placeholder: "Search")
                .padding(.horizontal, DODSpacing.md)
                .padding(.bottom, DODSpacing.sm)
                .accessibilityIdentifier("dod.search.field.categories")
            applyListStyle(baseList)
        }
        .background(DODColor.surface)
    }

    /// Applies the iOS-only `.listStyle(.insetGrouped)` to the base list.
    /// Split into a helper so the `loadedList` body stays an expression
    /// the type-checker resolves quickly and the `#if os(iOS)` branch
    /// doesn't fight `some View`'s opaque-type inference inside a
    /// `VStack` builder.
    @ViewBuilder
    private func applyListStyle<L: View>(_ baseList: L) -> some View {
        #if os(iOS)
        baseList.listStyle(.insetGrouped)
        #else
        baseList
        #endif
    }

    /// One row in the `.insetGrouped` list. Renders as an iOS-stock cell
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
