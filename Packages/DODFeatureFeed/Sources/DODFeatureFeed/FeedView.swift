import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

/// Home feed screen. Pull-to-refresh + infinite scroll + offline banner +
/// first-launch-offline empty state.
///
/// Tapping a row is broadcast via `onSelect` so the app composition root
/// can navigate without this module knowing about the detail feature.
public struct FeedView: View {

    // DUT-527 — `internal` (no `private`) so the helpers extracted to
    // `FeedView+Helpers.swift` (file-length relief) can read the view model,
    // mirroring how `SearchView`'s `@State var viewModel` is promoted for the
    // same cross-file-extension reason.
    @State var viewModel: FeedViewModel
    // DUT-534 Part 2 — internal (was `private`) so the card-list builders moved
    // to `FeedView+ShoppingList` can read the size class for adaptive layout.
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    /// US-38 / AC-38.2 / CL-64 (T-650, 2026-05-27) — shared with `SearchView`
    /// via the same `@AppStorage` key. Default `.gallery` preserves CC-9's
    /// 2-column grid byte-for-byte for users who never tap the toggle.
    @AppStorage(RecipeListLayout.storageKey) private var layoutRaw: String =
        RecipeListLayout.gallery.rawValue
    public let onSelect: (RecipeListItem) -> Void
    /// US-34 / AC-34.1 — long-press → "Save" context menu wiring. Optional
    /// so existing callers (tests, previews) don't need to plumb it. nil
    /// here means the context menu still appears but the Save button is a
    /// no-op; production callers (TabStack) always pass a non-nil closure
    /// that routes through `RecipeStore.toggleSaved` per CL-59.
    public let onSave: ((RecipeListItem) -> Void)?
    /// DUT-534 Part 2 — the Shopping List snackbar's "View" action opens the
    /// Shopping List (`dod://shopping-list`). Optional so existing callers
    /// (tests / previews) can omit it; when nil the append still works but the
    /// success snackbar shows no "View" button (mirrors Recipe Detail's Part 1
    /// `openShoppingList` seam threaded through `TabStack`).
    public let openShoppingList: (() -> Void)?
    /// T-912 / DUT-551 (CL-306) — opens the Settings sheet (Settings left the tab
    /// bar; the Feed header trailing slot now hosts the gear). Optional so
    /// existing callers (tests / previews) can omit it; nil renders no gear.
    /// Production wires it through `TabStack` → `RootView.showSettingsSheet`.
    public let onOpenSettings: (() -> Void)?

    public init(
        viewModel: FeedViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem) -> Void)? = nil,
        openShoppingList: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
        self.openShoppingList = openShoppingList
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // DUT-275 — the "Recipes & Articles" title + the header trailing
                // button share one header row at the very top (the nav bar is
                // hidden). With the button in the content row instead of the nav
                // bar, NO nav-bar height is reserved, so this title sits at the
                // exact same Y as every other tab's title. T-912 / DUT-551
                // (CL-306) — the trailing slot now hosts the Settings gear (the
                // old Cooking Tools menu + its onboarding callout are retired; the
                // tools moved to the first-class Cooking Tools hub tab).
                DODScreenHeader("Recipes & Articles") { settingsGear }
                content
            }
            // Offline shifts the whole stack below the OfflineBanner overlay.
            .padding(.top, viewModel.isOffline ? DODSpacing.xl : 0)
            OfflineBanner(isOffline: viewModel.isOffline)
        }
        // DUT-534 Part 2 — the "Add to Shopping List" confirmation snackbar,
        // anchored to the bottom (mirrors Recipe Detail's Part 1 host).
        .overlay(alignment: .bottom) { shoppingListSnackbar }
        .background(DODColor.surface)
        // DUT-275 — nav bar hidden: the header button lives in the pinned header
        // row above (next to the title) instead of the nav bar, so no nav-bar
        // height is reserved and the title sits at the same top Y as every other
        // tab. Pushed detail screens keep their own nav bar.
        .dodHidesNavBar()
        .task { await viewModel.onAppear() }
        // DUT-527 — `refreshAndAnnounce` runs the pull-to-refresh, then posts a
        // VoiceOver completion + result-count announcement (see FeedView+Helpers).
        .refreshable { await refreshAndAnnounce() }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isOffline)
        .sensoryFeedback(.success, trigger: viewModel.refreshCount)
    }

    /// T-912 / DUT-551 (CL-306) — the Settings gear in the Feed header trailing
    /// slot. Settings left the tab bar; the gear opens it as a sheet via the
    /// injected `onOpenSettings` closure (`RootView.showSettingsSheet`). Rendered
    /// only when wired, so tests / previews that omit the closure show no gear.
    @ViewBuilder
    private var settingsGear: some View {
        if let onOpenSettings {
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Settings")
            }
            .tint(DODColor.burntOrange)
            .accessibilityIdentifier("feed-toolbar-settings")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loadingInitial:
            loadingSkeletons
        case .firstLaunchOffline:
            EmptyState(
                systemImage: "wifi.slash",
                title: "You need internet",
                message: "Connect to load recipes the first time.",
                action: .init(title: "Retry") {
                    Task { await viewModel.refresh() }
                }
            )
        case .empty:
            EmptyState(
                systemImage: "tray",
                title: "No recipes",
                message: "Check back soon."
            )
        case .idle, .loaded, .loadingMore:
            list
        }
    }

    private var list: some View {
        // US-38 / AC-38.3 / AC-38.4 (T-650): branch on the persisted
        // layout. `.gallery` keeps the existing 2-col `LazyVGrid` body
        // byte-identical (CC-9 contract preserved); `.list` renders a
        // `LazyVStack` of `RecipeCard.ListRow` rows for denser scanning.
        // DUT-275 — the title is now pinned above `content` in `body`, and the
        // Cooking Tools callout floats as an overlay; `list` is just the grid.
        let layout = RecipeListLayout(rawValue: layoutRaw) ?? .gallery
        return ScrollView {
            Group {
                switch layout {
                case .gallery:
                    galleryContent
                case .list:
                    listContent
                }
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.top, DODSpacing.md)

            if viewModel.loadState == .loadingMore {
                ProgressView()
                    .padding(.vertical, DODSpacing.lg)
            }
        }
    }

    private var loadingSkeletons: some View {
        ScrollView {
            VStack(spacing: DODSpacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    LoadingSkeleton(cornerRadius: DODRadius.standard)
                        .frame(height: 280)
                }
            }
            .padding(DODSpacing.md)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading recipes")
        }
    }
}
