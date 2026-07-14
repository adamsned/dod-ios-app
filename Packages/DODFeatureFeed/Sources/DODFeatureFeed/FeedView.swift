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
    // DUT-700 PR-A — Reduce-Motion gate for the OfflineBanner ease.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    ///
    /// DUT-629 — the closure reports the store write's success via a completion
    /// (`@MainActor (Bool) -> Void`): the view flips its optimistic
    /// `savedRecipeIDs` membership before calling this, and re-inverts it when the
    /// completion reports `false`, so a failed write doesn't leave the menu
    /// showing a save that never persisted.
    public let onSave: ((RecipeListItem, @escaping @MainActor (Bool) -> Void) -> Void)?
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
    /// DUT-571 — the top-of-feed First-Cookout hero's "Let's Cook" action. Opens
    /// the guided path landing on the recommended rung. Optional so tests /
    /// previews can omit it (nil → the button is inert); production wires it
    /// through `TabStack` → `RootView.route(toHubTool: .firstCookout)`.
    public let onStartFirstCookout: (() -> Void)?
    /// DUT-571 — the hero's "Or Cook a Dump Cake" action. Opens the same guided
    /// path (the dump cakes live in `CookChooserFlow`'s "Anytime Treats"
    /// section — there's no distinct dump-cake route). Optional; wired through
    /// `TabStack` → `RootView.route(toHubTool: .firstCookout)`.
    public let onCookDumpCake: (() -> Void)?

    /// DUT-571 — the cook's real next un-cooked rung, loaded in a `.task` (see
    /// `FeedView+FirstCookoutHero`). `nil` before it loads OR once the cook has
    /// graduated the whole path; either way the hero stays hidden.
    @State var heroCookout: GuidedCookout?
    /// DUT-571 — flips true once `loadFirstCookoutHeroState()` has run, so the
    /// hero never flashes before the real cook state is known.
    @State var heroCookStateLoaded = false
    /// Daddy Mode (Phase 1, cosmetic) — whether the signed-in user is the app
    /// owner, resolved once on appear (avoids a Keychain read per body
    /// recompute). Gates the owner-only compose button; OFF for everyone until
    /// Dad's real `sub` is configured in `OwnerGate`.
    @State private var isOwnerComposer = false
    /// Daddy Mode (Phase 1, cosmetic) — presents the honest compose placeholder.
    @State private var showingComposeSheet = false
    /// DUT-571 — persisted dismissal (a once-per-install "x" tap). `.standard`
    /// mirrors the Feed's existing `RecipeListLayout` layout-toggle store.
    @AppStorage(FeedView.firstCookoutHeroDismissedKey) var firstCookoutHeroDismissed = false

    public init(
        viewModel: FeedViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem, @escaping @MainActor (Bool) -> Void) -> Void)? = nil,
        openShoppingList: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onStartFirstCookout: (() -> Void)? = nil,
        onCookDumpCake: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
        self.openShoppingList = openShoppingList
        self.onOpenSettings = onOpenSettings
        self.onStartFirstCookout = onStartFirstCookout
        self.onCookDumpCake = onCookDumpCake
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
                DODScreenHeader("Recipes & Articles") { headerTrailing }
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
        // Daddy Mode (Phase 1, cosmetic) — resolve owner status once for the
        // compose button gate. OFF for everyone until Dad's real `sub` is set.
        .task { isOwnerComposer = OwnerGate.isCurrentUserOwner() }
        // Daddy Mode (Phase 1, cosmetic) — the compose entry point's honest
        // placeholder sheet (owner-only; the button that sets this is gated).
        .sheet(isPresented: $showingComposeSheet) { ComposePlaceholderView() }
        .task { await viewModel.onAppear() }
        // DUT-571 — load the cook's real next rung for the top-of-feed hero card,
        // off the feed's own load so it never blocks the list. A separate `.task`
        // (its own lifecycle) keeps `onAppear`'s paging logic untouched.
        .task { await loadFirstCookoutHeroState() }
        // DUT-527 — `refreshAndAnnounce` runs the pull-to-refresh, then posts a
        // VoiceOver completion + result-count announcement (see FeedView+Helpers).
        .refreshable { await refreshAndAnnounce() }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.isOffline)
        .sensoryFeedback(.success, trigger: viewModel.refreshCount)
        // DUT — a `.selection` tap only on a genuine card long-press Save/Unsave
        // (keyed to `saveToggleCount`, not `savedRecipeIDs`, so the appear/refresh
        // reconciliation of the id set doesn't mis-fire the haptic, and a failed
        // write's silent rollback stays silent). Mirrors Categories (DUT-697).
        .sensoryFeedback(.selection, trigger: viewModel.saveToggleCount)
    }

    /// T-912 / DUT-551 (CL-306) — the Settings gear in the Feed header trailing
    /// slot. Settings left the tab bar; the gear opens it as a sheet via the
    /// injected `onOpenSettings` closure (`RootView.showSettingsSheet`). Rendered
    /// only when wired, so tests / previews that omit the closure show no gear.
    /// Uses the shared, bigger ``DODHeaderGearButton`` so the gear matches the
    /// Saved / Cooking Tools / Search headers exactly.
    /// The Feed header's trailing slot. Groups the owner-only compose button
    /// (Daddy Mode, Phase 1) with the long-standing Settings gear in one HStack
    /// (`DODScreenHeader`'s trailing is a single `@ViewBuilder`). The compose
    /// button self-gates on owner status, so non-owners see only the gear —
    /// byte-identical to the pre-Daddy-Mode header.
    @ViewBuilder
    private var headerTrailing: some View {
        HStack(spacing: DODSpacing.xs) {
            surpriseMeButton
            composeButton
            settingsGear
        }
    }

    /// DUT-939 — "Surprise Me" (Android parity: Android already ships a
    /// random-recipe entry point, iOS didn't). Mirrors ``composeButton``'s
    /// styling (44pt hit target, burnt-orange tint) so it reads as the same
    /// family of header affordance as the gear/compose buttons. Disabled
    /// (not hidden) while the feed has no items yet, so the header layout
    /// never shifts as the initial load resolves.
    ///
    /// DUT-1062: `surpriseMe(onSelect:)` is now `async` — it fetches a truly
    /// random recipe from the full WP catalog (falling back to the old
    /// in-memory sample only if that fetch fails), so the tap now spawns a
    /// `Task` and the button shows a spinner in place of the dice glyph
    /// while `isSurpriseMeLoading`, plus disables re-tapping mid-fetch.
    @ViewBuilder
    private var surpriseMeButton: some View {
        Button {
            Task { await viewModel.surpriseMe(onSelect: onSelect) }
        } label: {
            Group {
                if viewModel.isSurpriseMeLoading {
                    ProgressView()
                } else {
                    Image(systemName: "dice.fill")
                        .font(.title2)
                }
            }
            .accessibilityLabel("Surprise Me")
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .tint(DODColor.burntOrange)
        .accessibilityIdentifier("feed-surprise-me")
        .disabled(viewModel.items.isEmpty || viewModel.isSurpriseMeLoading)
    }

    /// Daddy Mode (Phase 1, cosmetic) — the owner-only compose entry point.
    /// Mirrors ``DODHeaderGearButton``'s styling (44pt hit target, burnt-orange
    /// tint). Tapping presents the honest ``ComposePlaceholderView`` sheet;
    /// authorizes nothing. Hidden entirely for non-owners.
    @ViewBuilder
    private var composeButton: some View {
        if isOwnerComposer {
            Button {
                showingComposeSheet = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title2)
                    .accessibilityLabel("Compose Post")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .tint(DODColor.burntOrange)
            .accessibilityIdentifier("feed-compose-button")
        }
    }

    @ViewBuilder
    private var settingsGear: some View {
        // DUT-572 — gear only in compact width (iPhone). On iPad (regular width)
        // the sidebar already hosts a Settings row, so the per-header gear is
        // redundant; gating to compact hides it there while iPhone is unchanged.
        if let onOpenSettings, horizontalSizeClass == .compact {
            // Feed keeps its long-standing `feed-toolbar-settings` id (the
            // SmokeTests + AppShell E2E journeys query it), set directly on the
            // button via the component's param — not an ambiguous outer override.
            DODHeaderGearButton(accessibilityID: "feed-toolbar-settings") { onOpenSettings() }
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
        case .firstLaunchFailed:
            // DUT-621 — an ONLINE first-launch failure: a real failure message
            // + a Retry wired to `refresh()`, NOT the dead-end "No recipes."
            // Hosted in a ScrollView so the pull-to-refresh gesture works here
            // too (a bounce-to-refresh alongside the explicit Retry button).
            ScrollView {
                EmptyState(
                    systemImage: "exclamationmark.arrow.triangle.2.circlepath",
                    title: "Couldn't load recipes",
                    message: "Something went wrong loading the feed. Please try again.",
                    action: .init(title: "Retry") {
                        Task { await viewModel.refresh() }
                    }
                )
                .frame(maxWidth: .infinity, minHeight: 400)
            }
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
            // DUT-571 — the First-Cookout hero sits ABOVE the recipe list, once
            // for both layouts. `firstCookoutHero` self-gates (new / un-graduated,
            // non-dismissed cook only) and carries its own padding, so it and its
            // spacing vanish entirely (no reserved gap) for everyone else.
            firstCookoutHero
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
