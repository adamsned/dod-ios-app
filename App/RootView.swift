import CoreSpotlight
import DODAnalytics
import DODDesignSystem
import DODFeatureFeed
import DODFeatureProfile
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
    @State private var selectedTab: AppTab = .feed
    /// T-762 / CL-159 (DUT-68) — drives the single first-launch welcome sheet
    /// (US-8). The former second sheet (the iCloud-Sync opt-in, AC-41.2) is
    /// removed; sync is opt-in only from Settings (AC-41.3) now, and the
    /// welcome sheet mentions it as a capability instead.
    @State private var showOnboarding: Bool
    /// First-run iCloud-Sync opt-in prompt, shown once right after the welcome
    /// sheet on a brand-new install (paired with the notification permission
    /// request). Re-introduces a launch-time *ask* for sync — DUT-68 removed the
    /// old blocking opt-in sheet, but a new user was then never asked, so their
    /// saved recipes never synced. "Turn On" sets the opt-in (effective next
    /// launch); "Not Now" leaves it off (still changeable in Settings).
    @State var showCloudSyncPrompt = false
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
    @State private var pendingDeepLink: WidgetDeepLink?
    /// App Intents / Spotlight route (spec.md US-10).
    @State private var feedExternalRoute: RecipeRoute?
    @State private var dispatcher = DeepLinkDispatcher.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The system `openURL`, captured before RootView overrides it for its
    /// descendants — used to defer non-recipe article links to the browser
    /// (DOD-ART-2).
    @Environment(\.openURL) private var systemOpenURL
    /// Foreground Spotlight refresh (DUT-12); see `reindexSpotlightOnForeground`.
    @Environment(\.scenePhase) private var scenePhase
    @State private var didInitialSpotlightIndex = false
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
        .onChange(of: scenePhase) { reindexSpotlightOnForeground($1) }
        .onChange(of: dispatcher.pending) { _, newValue in
            guard let newValue else { return }
            handle(intent: newValue)
            dispatcher.consume()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            // DUT-335 — the App Intro: a paged feature tour. Presented full-screen
            // (no swipe-to-dismiss, so it can't be escaped without finishing —
            // the DUT-301 concern the old sheet handled with
            // `interactiveDismissDisabled`). The persistent "Let's Get Cooking"
            // CTA is the single exit: it sets the onboarding flag + kicks off
            // first-run setup.
            AppIntroTour(
                pages: Self.appIntroPages,
                ctaTitle: "Let's Get Cooking",
                onFinish: {
                    guard showOnboarding else { return }  // DUT-407: ignore a double-tap
                    UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
                    showOnboarding = false
                    // First-run: ask for notifications + iCloud Sync (skipped
                    // under the onboarding UI test, which can't dismiss the
                    // system permission dialogs).
                    if !DODEnvironment.suppressFirstRunPrompts {
                        Task { await runFirstRunSetup() }
                    }
                }
            )
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
        // Intercept in-app link taps (DOD-ART-2): a dutchovendaddy.com recipe
        // link inside a rendered article opens the recipe in-app instead of
        // bouncing to Safari. Set on the whole tree so it reaches the article
        // body's `Text` links in every tab; non-recipe / off-site URLs defer
        // to the system handler.
        .environment(\.openURL, OpenURLAction { url in handleArticleLinkTap(url) })
    }

    private var phoneTabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                TabStack(
                    tab: tab,
                    dependencies: dependencies,
                    pendingDeepLink: tab == .feed ? $pendingDeepLink : .constant(nil),
                    externalRoute: tab == .feed ? $feedExternalRoute : .constant(nil)
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
        .onChange(of: selectedTab) { _, newValue in
            Telemetry.shared.send(.screenView(name: newValue.telemetryName))
        }
        .onAppear {
            Telemetry.shared.send(.screenView(name: AppTab.feed.telemetryName))
        }
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
                pendingDeepLink: selectedTab == .feed ? $pendingDeepLink : .constant(nil),
                externalRoute: selectedTab == .feed ? $feedExternalRoute : .constant(nil)
            )
            .id(selectedTab)
        }
        .tint(DODColor.accent)
        .onChange(of: selectedTab) { _, newValue in
            Telemetry.shared.send(.screenView(name: newValue.telemetryName))
        }
    }

    // MARK: - Deep-link routing

    /// Widget URL handler (spec.md US-9 AC-9.2, US-17 AC-17.4). For
    /// recipe + feed routes, switches to Feed and hands the link to the
    /// TabStack via the `pendingDeepLink` binding. For the saved route
    /// (US-17), the Saved tab owns the destination directly so we just
    /// switch tabs — no pending-link push.
    ///
    /// Fires `widgetOpened(kind:, recipeID:)` once per consumed link
    /// (T-323 / AC-17.9). The kind reflects which widget surface the tap
    /// came from — the parser inspects the URL's `source` query parameter
    /// for recipe URLs and the host name itself for chrome URLs. Per
    /// constitution §9 (US-17 amendment) the payload carries only the
    /// kind plus an integer recipe id (or nil for chrome / empty-state
    /// taps that land on the Saved or Feed tab without a specific
    /// recipe target).
    private func handle(widgetLink link: WidgetDeepLink) {
        Telemetry.shared.send(.widgetOpened(kind: link.widgetKind, recipeID: link.recipeID))
        switch link {
        case .saved:
            selectedTab = .saved
        case .feed:
            selectedTab = .feed
            pendingDeepLink = link
        case .recipe(let id, _):
            // DUT-358: route a widget recipe tap through the App-Intent fetch-on-miss
            // resolver, so a cache + snapshot double-miss fetches the recipe instead
            // of `TabStack.consume` silently dropping the tap.
            selectedTab = .feed
            handle(intent: .openRecipe(id: id))
        }
    }

    /// Routes a parsed `DeepLinkIntent` into tab + path state (US-10).
    private func handle(intent: DeepLinkIntent) {
        switch intent {
        case .openSaved:
            selectedTab = .saved
        case .openRecipe(let id):
            selectedTab = .feed
            Task { @MainActor in
                guard let route = await resolveRecipeRoute(id: id, autoStartCookMode: false) else {
                    return
                }
                feedExternalRoute = route
            }
        case .startCookMode(let recipeID):
            selectedTab = .feed
            Task { @MainActor in
                guard
                    let route = await resolveRecipeRoute(
                        id: recipeID,
                        autoStartCookMode: true
                    )
                else { return }
                feedExternalRoute = route
            }
        }
    }

    /// Resolve a deep-link recipe/post id into a route, fetching on a cache
    /// miss (T-632 / REG-20 / CL-101). Cache-hit (widget / Spotlight) stays
    /// network-free; cache-miss (notification — the post is brand-new and
    /// never cached) fetches the post by id so its `canonicalURL` is known,
    /// then routes to recipe-detail, which classifies recipe-vs-article via
    /// its existing JSON-LD fetch path (AC-4.11 / AC-37.2). The policy lives
    /// in ``RecipeRouteResolver`` so it is unit-testable without a SwiftUI
    /// host; this method just supplies the two live I/O edges.
    private func resolveRecipeRoute(id: Int, autoStartCookMode: Bool) async -> RecipeRoute? {
        await RecipeRouteResolver.resolve(
            id: id,
            autoStartCookMode: autoStartCookMode,
            cachedLookup: { try await dependencies.store.recipeWithoutTouching(id: $0) },
            fetch: { try await dependencies.fetchListItem(forPostID: $0) }
        )
    }

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
    /// `.system` returns `nil` so `.preferredColorScheme(...)` becomes a
    /// no-op and the OS-level setting drives every screen — matches the
    /// "Match System" default. T-756 / CL-153 — delegates to the shared
    /// ``AppearancePreference/colorScheme`` so RootView (main window) and
    /// SettingsView (the sheet's own live theme) map identically.
    private func preferredColorScheme(for value: AppearancePreference) -> ColorScheme? {
        value.colorScheme
    }
}

// MARK: - DOD-ART-2 in-app article-link routing

extension RootView {
    /// Re-index Spotlight on each foreground return so later-session saves stay
    /// searchable without a cold launch; the launch `.active` is gated (DUT-12).
    func reindexSpotlightOnForeground(_ newPhase: ScenePhase) {
        guard newPhase == .active, didInitialSpotlightIndex else { return }
        Task { await indexSpotlight() }
    }

    /// Custom `openURL` handler for in-app article recipe links. A
    /// `dutchovendaddy.com` link is resolved to its post and pushed into the
    /// Feed stack (the same surface Spotlight / Siri / notifications route to);
    /// a non-recipe `dutchovendaddy.com` URL or any off-site URL opens in the
    /// browser. Returns synchronously — the resolve is a fire-and-forget Task.
    /// Lives in an extension so the deep-link addition stays under the
    /// `type_body_length` cap on the (already large) `RootView` struct.
    func handleArticleLinkTap(_ url: URL) -> OpenURLAction.Result {
        guard AppDependencies.recipeSlug(fromDODURL: url) != nil else {
            return .systemAction
        }
        Task { @MainActor in
            if let item = await dependencies.resolveRecipe(forArticleLink: url) {
                selectedTab = .feed
                feedExternalRoute = .recipe(item: item, autoStartCookMode: false)
            } else {
                systemOpenURL(url)
            }
        }
        return .handled
    }
}
