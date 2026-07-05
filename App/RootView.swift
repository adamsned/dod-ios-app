import CoreSpotlight
import DODAnalytics
import DODDesignSystem
import DODFeatureFeed
import DODFeatureProfile
import DODFeatureRecipeDetail
import DODSupport
import SwiftUI

/// Top-level shell. TabView on compact widths (iPhone), NavigationSplitView on
/// iPad regular. Per-tab navigation lives in `TabStack` so each NavigationStack
/// owns its own @State path — that's the fix for DOD-NAV-1.
struct RootView: View {

    /// `UserDefaults` key that gates the first-launch welcome sheet. Persisted
    /// as a bool — `true` once the user dismisses the sheet, never set again.
    /// The `V1` suffix is intentional: if we ever want to re-show onboarding
    /// after a major redesign we bump to `V2` rather than reading the old key.
    /// Spec trace: US-8 (post-launch amendment to CL-7).
    static let onboardingCompletedKey = "dod.onboardingCompletedV1"
    /// DUT-280 — gates the first-run permission prompts (notifications + iCloud
    /// Sync) INDEPENDENTLY of the onboarding-completed flag. Set true only after
    /// both prompts are answered/dismissed, so a kill mid-flow re-runs them next
    /// launch instead of losing them forever (the prompts were coupled to the
    /// one-shot onboarding flag, which is committed before they run).
    static let firstRunPromptsCompletedKey = "dod.firstRunPromptsCompletedV1"

    // Non-private so the `+Onboarding.swift` extension's `runFirstRunSetup` can
    // reach it.
    @State var dependencies: AppDependencies
    // Non-private so the `+LinkRouting.swift` extension can route into the
    // currently-selected tab (DUT-243).
    @State var selectedTab: AppTab = .feed
    /// T-762 / CL-159 (DUT-68) — drives the single first-launch welcome sheet
    /// (US-8). The former second sheet (the iCloud-Sync opt-in, AC-41.2) is
    /// removed; sync is opt-in only from Settings (AC-41.3) now, and the
    /// welcome sheet mentions it as a capability instead.
    /// Non-private so the `+Onboarding.swift` extension's `onboardingCover`
    /// (extracted for file_length) can read/flip it (DUT-529).
    @State var showOnboarding: Bool
    /// First-run iCloud-Sync opt-in prompt, shown once right after the welcome
    /// sheet on a brand-new install (paired with the notification permission
    /// request). Re-introduces a launch-time *ask* for sync — DUT-68 removed the
    /// old blocking opt-in sheet, but a new user was then never asked, so their
    /// saved recipes never synced. "Turn On" sets the opt-in (effective next
    /// launch); "Not Now" leaves it off (still changeable in Settings).
    @State var showCloudSyncPrompt = false
    /// DUT-408 / DUT-529 — set by `runFirstRunSetup(presentingFromCoverDismiss:)`
    /// when the iCloud-Sync prompt must wait for the onboarding cover to finish
    /// dismissing. The cover's `onDismiss:` reads and clears this to fire
    /// `showCloudSyncPrompt`, so the alert presents *after* the dismiss animation
    /// completes rather than being swallowed mid-dismiss (replaces the old fixed
    /// 450 ms sleep).
    @State var pendingCloudSyncPromptAfterOnboarding = false
    /// US-36 AC-36.2 — user-selected appearance preference. Backed by
    /// `UserDefaults` (key `dod.settings.appearance`) via `@AppStorage`
    /// so a write from `SettingsViewModel.appearance` (the Picker's
    /// setter) lands here in the same frame. Applied to the root
    /// `Group` via `.preferredColorScheme(...)`. When the value is
    /// `.system` the modifier receives `nil` and the OS-level setting
    /// drives every screen's color scheme.
    @AppStorage(SettingsViewModel.appearancePreferenceKey)
    private var appearanceRaw: String = AppearancePreference.system.rawValue
    /// Widget deep link (spec.md US-9 AC-9.2). Feed tab consumes via .task(id:).
    /// Non-private so `+LinkRouting.swift`'s `handle(widgetLink:)` can set it.
    @State var pendingDeepLink: WidgetDeepLink?
    /// DUT-549 — a deep link / notification whose recipe fails BOTH cache and
    /// network resolution surfaces this transient snackbar instead of dumping
    /// the user on a blank Feed. Set by `handle(intent:)`; the overlay +
    /// `deepLinkFailedMessage` copy live in `RootView+LinkRouting.swift`.
    @State var deepLinkErrorMessage: String?
    // Per-tab external-route sinks. Feed carries deep links (App Intents /
    // Spotlight, spec.md US-10, replace semantics) AND in-app link taps;
    // Saved + Search exist so an article link tapped there opens in place
    // instead of yanking the user to Feed (DUT-243, push semantics).
    // Non-private so the `+LinkRouting.swift` extension can write them.
    //
    // DUT-463 / DUT-464 / DUT-319 — these were single-slot `ExternalRoute?`
    // mailboxes that dropped routes (a second one overwrote the first; one
    // resolved while the tab was unmounted sat stuck, then wiped the stack
    // later). Now a FIFO ``ExternalRouteQueue`` per tab holds every enqueued
    // route and `TabStack` drains it on appear + on change, dropping stale ones.
    @State var feedExternalRoute = ExternalRouteQueue()
    @State var savedExternalRoute = ExternalRouteQueue()
    @State var searchExternalRoute = ExternalRouteQueue()
    /// DUT-250 — per-tab navigation stacks, hoisted out of `TabStack`'s local
    /// `@State` into `RootView` so they SURVIVE the iPad size-class flip. `body`
    /// swaps structurally different trees at the `.regular` boundary —
    /// `iPadSplit` (one detail `TabStack`, keyed `.id(selectedTab)`) vs
    /// `phoneTabs` (four) — so TabStack identities differ and SwiftUI tore down
    /// the old stack (and its local `path`). `RootView` survives the flip (like
    /// `selectedTab`), so a path owned here does too; each `TabStack` reads its
    /// slot via `pathBinding(for:)`. `.id(selectedTab)` on the iPad detail is
    /// kept (resets the TabStack's *other* @State). Non-private for the ext.
    @State var tabPaths: [AppTab: [RecipeRoute]] = [:]
    /// DUT-546 (gap 3) — ONE app-level moderation store injected into every
    /// `RecipeDetailViewModel` (via `TabStack`), so a block on one open recipe
    /// screen updates an already-open second one live (the `@Observable` set is
    /// process-wide) instead of each screen reading its own `UserDefaults` copy.
    /// Owned here (survives the iPad flip like `selectedTab`). Non-private for
    /// the `TabStack` construction sites.
    @State var commentModeration = CommentModerationStore()
    /// T-912 / DUT-551 (CL-306) — Settings left the tab bar; it's presented as a
    /// sheet from the Feed header gear (iPhone) / iPad sidebar Settings row.
    @State var showSettingsSheet = false
    /// DUT-560 — the hub's UNIFIED tool reroute request (replaces the per-tool
    /// `hubShoppingListToken` / `hubHeatCoachToken`). `route(toHubTool:)` selects
    /// `.cookingTools` + mints a fresh `HubToolRoute`; the hub opens the tool via
    /// `.task(id:)`. Owned here so it survives the iPad flip. Mirrors CL-301.
    @State var hubPendingTool: HubToolRoute?
    /// DUT-461 (revised) — the hub's Cooking Tip token. The Cooking Tip widget's
    /// `dod://tip/<index>` tap mints it (via `handle(widgetLink: .tip)`); the hub
    /// consumes it via `.task(id:)` to pop to its root so the persistent tip banner
    /// at the top is visible. Owned here so it survives the iPad flip.
    @State var hubTipToken: UUID?
    @State private var dispatcher = DeepLinkDispatcher.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The system `openURL`, captured before RootView overrides it for its
    /// descendants — used to defer non-recipe article links to the browser
    /// (DOD-ART-2). Non-private for the `+LinkRouting.swift` extension.
    @Environment(\.openURL) var systemOpenURL
    /// Foreground Spotlight refresh (DUT-12); see `reindexSpotlightOnForeground`.
    @Environment(\.scenePhase) private var scenePhase
    // Non-private for `RootView+Spotlight.swift`'s foreground-reindex guard.
    @State var didInitialSpotlightIndex = false
    /// DUT-361: serializes `indexSpotlight()` so a foreground reindex can't race the
    /// cold-launch index (concurrent delete+index can interleave the domain). Not
    /// `private` so the `+Spotlight` extension file can read it.
    @State var isIndexingSpotlight = false

    init(dependencies: AppDependencies) {
        _dependencies = State(initialValue: dependencies)
        // T-762 / CL-159 — show the single welcome sheet on brand-new installs
        // only (US-8). The former second sheet (iCloud-Sync opt-in) is gone;
        // sync opt-in lives in Settings (AC-41.3).
        let onboardingDone = UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey)
        _showOnboarding = State(initialValue: !onboardingDone)
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadSplit
            } else {
                phoneTabs
            }
        }
        .preferredColorScheme(preferredColorScheme(for: appearance))
        .animation(.easeInOut(duration: 0.2), value: appearance)
        .task {
            await dependencies.bootstrap()
            migrateFirstRunFlagsIfNeeded()  // DUT-400
            // DUT-280 — recover the first-run prompts if a prior launch dismissed
            // onboarding but didn't finish them (killed mid-flow). The welcome
            // sheet itself is NOT re-shown; only the prompts re-run.
            let needsFirstRunPrompts =
                !showOnboarding && !DODEnvironment.suppressFirstRunPrompts
                && !UserDefaults.standard.bool(forKey: Self.firstRunPromptsCompletedKey)
            if needsFirstRunPrompts {
                await runFirstRunSetup()
            }
            // DUT-352: drain an intent that arrived during cold launch before the
            // `.onChange(of: dispatcher.pending)` observer attached (onChange doesn't
            // fire for a value already set when the observer installs).
            if let pending = dispatcher.pending {
                handle(intent: pending)
                dispatcher.consume()
            }
            // DUT-480 — cold launch straight from the iOS 18 Control Center
            // control (app wasn't running) still drains the pending-route flag;
            // the scene-phase `.active` read below covers the warm case.
            consumePendingControlRoute()
            // Cold-launch index so DOD recipes are findable in Spotlight right
            // away; the foreground refresh below keeps it fresh (US-10 / DUT-12).
            await indexSpotlight()
            didInitialSpotlightIndex = true  // arm the foreground re-index
        }
        .onOpenURL { url in
            // Widget deep links route through WidgetDeepLink; App-Intents URLs
            // route through DeepLinkIntent. Try widget first (narrower), then
            // intent fallback.
            if let link = WidgetDeepLink(url: url) {
                handle(widgetLink: link)
                return
            }
            if let intent = DeepLinkIntent.parse(url) {
                handle(intent: intent)
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard
                let identifier = activity.userInfo?[
                    CSSearchableItemActivityIdentifier
                ] as? String,
                let id = identifier.split(separator: ".").last.flatMap({ Int($0) })
            else { return }
            handle(intent: .openRecipe(id: id))
        }
        .onChange(of: scenePhase) {
            reindexSpotlightOnForeground($1)
            // DUT-480 — a Control Center tap set `openAppWhenRun`, so it
            // foregrounds us here; drain the pending-route flag and route.
            if $1 == .active { consumePendingControlRoute() }
        }
        .onChange(of: dispatcher.pending) { _, newValue in
            guard let newValue else { return }
            handle(intent: newValue)
            dispatcher.consume()
        }
        // DUT-335 — the App Intro paged feature tour. Presented full-screen (no
        // swipe-to-dismiss, so it can't be escaped without finishing — the
        // DUT-301 concern). The "Let's Get Cooking" CTA is the single exit.
        // DUT-408 / DUT-529 — `onDismiss:` presents the iCloud-Sync prompt only
        // after the cover's dismiss animation completes (this fires afterwards),
        // so iOS can't swallow it as present-during-dismiss (replaces the old
        // fixed 450 ms sleep in `runFirstRunSetup`).
        .fullScreenCover(
            isPresented: $showOnboarding,
            onDismiss: presentCloudSyncPromptIfPending,
            content: { onboardingCover }
        )
        // T-912 / DUT-551 (CL-306) — Settings sheet. The iPhone gear + iPad
        // sidebar row both flip `showSettingsSheet`.
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView(
                    viewModel: dependencies.settingsSheetViewModel(),
                    onClearImageCache: { try await dependencies.store.clearImageCache() },
                    // DUT-572 — hide the Profile row on iPad. This reads RootView's
                    // TRUE device size class (the same signal that selects iPadSplit
                    // vs phoneTabs); the sheet itself always reports `.compact`, so
                    // the flag must be resolved here and injected.
                    hidesProfile: horizontalSizeClass == .regular
                )
            }
        }
        .alert("Turn On iCloud Sync?", isPresented: $showCloudSyncPrompt) {
            Button("Turn On Sync") {
                // DUT-280 — both prompts answered; mark complete so they never re-run.
                UserDefaults.standard.set(true, forKey: Self.firstRunPromptsCompletedKey)
                Task { await dependencies.settingsDependencies().setCloudSyncOptIn(true) }
            }
            Button("Not Now", role: .cancel) {
                UserDefaults.standard.set(true, forKey: Self.firstRunPromptsCompletedKey)
            }
        } message: {
            Text(
                "Keep your saved recipes and cook journal on all your devices. "
                    + "Takes effect next time you open the app — change it anytime in Settings."
            )
        }
        // DUT-549 — transient "couldn't open that recipe" toast for a failed
        // deep-link resolve (modifier + copy in `RootView+LinkRouting.swift`).
        .modifier(DeepLinkErrorSnackbar(message: $deepLinkErrorMessage))
        // Intercept in-app link taps (DOD-ART-2): a dutchovendaddy.com recipe
        // link inside a rendered article opens the recipe in-app instead of
        // bouncing to Safari. Set on the whole tree so it reaches the article
        // body's `Text` links in every tab; non-recipe / off-site URLs defer
        // to the system handler.
        .environment(\.openURL, OpenURLAction { url in handleArticleLinkTap(url) })
        // DUT-246 — the awaitable variant of the same routing, for flows that
        // must know when (and whether) navigation happened before tearing
        // themselves down (the First Cookout sheet's "Open the recipe").
        .environment(\.recipeLinkOpener, RecipeLinkOpener { url in await openRecipeLink(url) })
    }

    private var phoneTabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                TabStack(
                    tab: tab,
                    dependencies: dependencies,
                    path: pathBinding(for: tab),
                    pendingDeepLink: tab == .feed ? $pendingDeepLink : .constant(nil),
                    externalRoute: externalRouteBinding(for: tab),
                    // T-912/DUT-551 — Shopping List entry points reroute to the
                    // hub; the gear opens Settings; Cook Mode routes to Recipes.
                    openShoppingList: { routeToShoppingList() },
                    onOpenSettings: { showSettingsSheet = true },
                    onFindRecipe: { selectedTab = .feed },
                    // T-912/DUT-551 — the per-recipe Heat Coach nudge routes here.
                    openHeatCoach: { routeToHeatCoach() },
                    hubPendingTool: tab == .cookingTools ? $hubPendingTool : .constant(nil),
                    hubTipToken: tab == .cookingTools ? $hubTipToken : .constant(nil),
                    // DUT-546 — one shared moderation store across every recipe screen.
                    commentModeration: commentModeration
                )
                .tabItem {
                    // T-660 / CL-65: bottom-tab `Label` reads `tabLabel`
                    // (short — "Recipes" for `.feed`) so the tab-bar's
                    // ~80pt fixed-width slot doesn't truncate the
                    // "Recipes & Articles" rename to "Recipes & Arti...".
                    // The screen-header `navigationTitle` continues to
                    // render the full `title`.
                    Label(tab.tabLabel, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .tint(DODColor.accent)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .modifier(ScreenViewTracking(selectedTab: selectedTab))
    }

    private var iPadSplit: some View {
        let selectionBinding = Binding<AppTab?>(
            get: { selectedTab },
            set: { selectedTab = $0 ?? selectedTab }
        )
        return NavigationSplitView {
            List(selection: selectionBinding) {
                // T-783 / DUT-89 — Profile pinned at the top of the sidebar
                // (moved from Settings on iPad). Untagged, so it's not a tab
                // selection target — its Button opens the editor as a sheet.
                Section {
                    SidebarProfileRow(
                        profileStore: dependencies.profileStore,
                        profilePhotoStore: dependencies.profilePhotoStore
                    )
                }
                Section {
                    ForEach(AppTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                    // T-912 / DUT-551 (CL-306) — Settings is an UNTAGGED sidebar
                    // row on iPad (not a tab target, like `SidebarProfileRow`);
                    // its Button opens the same sheet the iPhone gear does.
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .foregroundStyle(DODColor.label)
                    }
                    .accessibilityIdentifier("sidebar-settings-row")
                }
            }
            // T-784 / DUT-90 — no brand title in the sidebar. The Profile row
            // (pinned above) reads as the header, so a separate "Dutch Oven
            // Daddy" large title just crowds an already-busy sidebar. Empty +
            // inline collapses the large-title band so the Profile row rises to
            // the top.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.sidebar)
        } detail: {
            // Re-instantiate per tab change so @State in TabStack resets cleanly.
            TabStack(
                tab: selectedTab,
                dependencies: dependencies,
                path: pathBinding(for: selectedTab),
                pendingDeepLink: selectedTab == .feed ? $pendingDeepLink : .constant(nil),
                externalRoute: externalRouteBinding(for: selectedTab),
                // T-912/DUT-551 — Shopping List reroute + hub Cook Mode → Recipes.
                openShoppingList: { routeToShoppingList() },
                // DUT-563 — wire the header gear on iPad too (the phone branch
                // already does). Without this the detail `TabStack` took the
                // default no-op `{}`, so the rendered gear was a dead button.
                onOpenSettings: { showSettingsSheet = true },
                onFindRecipe: { selectedTab = .feed },
                // T-912/DUT-551 — the per-recipe Heat Coach nudge routes here.
                openHeatCoach: { routeToHeatCoach() },
                hubPendingTool: selectedTab == .cookingTools ? $hubPendingTool : .constant(nil),
                hubTipToken: selectedTab == .cookingTools ? $hubTipToken : .constant(nil),
                // DUT-546 — one shared moderation store across every recipe screen.
                commentModeration: commentModeration
            )
            .id(selectedTab)
        }
        .tint(DODColor.accent)
        .modifier(ScreenViewTracking(selectedTab: selectedTab))
    }

    // MARK: - Deep-link routing
    //
    // `handle(widgetLink:)`, `handle(intent:)`, and `resolveRecipeRoute(id:…)`
    // live in `RootView+LinkRouting.swift` (keeps this file under the SwiftLint
    // `file_length` cap).

    // MARK: - Appearance (US-36 AC-36.2)

    /// Decode the `@AppStorage`-backed raw value into a typed enum. An
    /// absent / malformed value falls back to `.system` so users always
    /// see a sensible default — same defensive fallback
    /// `AppearancePreference.fromDefaults(_:)` implements for the
    /// non-`@AppStorage` read path.
    private var appearance: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    /// Map the user-selected preference onto SwiftUI's `ColorScheme?`.
    /// `.system` returns `nil` so `.preferredColorScheme(...)` is a no-op and the
    /// OS drives every screen. T-756 / CL-153 — delegates to the shared
    /// ``AppearancePreference/colorScheme`` so RootView + SettingsView map identically.
    private func preferredColorScheme(for value: AppearancePreference) -> ColorScheme? {
        value.colorScheme
    }
}
