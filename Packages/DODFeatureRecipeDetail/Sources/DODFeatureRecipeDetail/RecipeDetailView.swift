import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

/// Recipe detail screen. Header (AC-4.1) + ingredients (AC-4.2) + instructions
/// (AC-4.3) + optional video (AC-4.4, AC-4.5) + related (AC-4.6) +
/// save (AC-4.7) + share (AC-4.8). VoiceOver labels (AC-4.10).
/// Offline-aware (AC-4.9, AC-5.4, AC-5.5).
/// Cook Now CTA presents Cook Mode (US-7).
public struct RecipeDetailView: View {

    // `internal` (not `private`) so the `RecipeDetailView+Sections.swift`
    // extension can attach these ids to the ingredients / Cook Mode + instructions
    // blocks it now owns (DUT-631).
    enum SectionAnchor: Hashable {
        case ingredients
        case instructions
    }

    /// DUT-535 — a fresh-identity wrapper for the recipe driving the
    /// ingredient-selection `.sheet(item:)`. A per-presentation `UUID` id (not
    /// the recipe's own id) so re-tapping "Add to Shopping List" for the same
    /// recipe re-presents the sheet.
    struct SheetRecipe: Identifiable {
        let id = UUID()
        let recipe: Recipe
    }

    // `internal` (default) access so the `RecipeDetailView+Blurb.swift`
    // extension can read `viewModel` to render the full-description surface
    // (Swift extensions don't see `private`/`fileprivate` declarations from a
    // sibling file).
    @State var viewModel: RecipeDetailViewModel
    @State private var isOfflineSnapshot: Bool = false
    /// Share has no toggle state (unlike Save / Download), so this counter is the
    /// `.sensoryFeedback` trigger, bumped in the ShareLink tap gesture (see
    /// `RecipeDetailView+Toolbar.swift`). `internal` so the extension bumps it.
    @State var shareTapCount: Int = 0
    // `internal` (not `private`) so the `RecipeDetailView+Sections.swift`
    // extension's relocated Cook Mode CTA tap can present the cover (DUT-631).
    @State var isCookModePresented: Bool = false
    /// True when the screen was entered via the StartCookModeIntent deep
    /// link (US-10). We watch the load state and flip the cover open as
    /// soon as the recipe has instructions to render. Resets to false
    /// after firing so a manual exit + re-entry behaves normally.
    /// `internal` (not `private`) so `RecipeDetailView+LoadStateChange.swift`
    /// (split out for the file-length cap, DUT-1240) can consume it.
    @State var pendingAutoCookMode: Bool
    /// DUT-47 (temperature half) — the user's recipe-step temperature unit
    /// preference, read from the same `UserDefaults` key Settings writes
    /// (`TemperatureConverter.preferenceKey`) via `@AppStorage` so a change
    /// in Settings re-renders the instructions in the same frame. The raw
    /// string is resolved to an optional `TemperatureUnit` by
    /// ``DODSupport/TemperatureConverter/resolvedUnit(fromRawValue:)``;
    /// `nil` ("Recipe default" / absent / malformed) means the converter is
    /// NOT applied and steps render exactly as the author wrote them. This
    /// is a display-time transform only — stored recipe data is untouched.
    @AppStorage(TemperatureConverter.preferenceKey)
    var temperatureUnitRaw: String = ""
    /// DUT-517 — the "Use Metric Units" preference, read from the same
    /// `UserDefaults` key the Settings toggle writes
    /// (`IngredientMetricConverter.preferenceKey`) via `@AppStorage` so a
    /// change in Settings re-renders the ingredient list in the same frame.
    /// When `true`, each ALREADY-SCALED ingredient line is mapped through
    /// ``DODSupport/IngredientMetricConverter/metric(_:)`` at display time;
    /// non-convertible lines pass through unchanged. Display-time transform
    /// only — stored recipe data is untouched (AC-31.8-style).
    @AppStorage(IngredientMetricConverter.preferenceKey)
    var useMetricUnits: Bool = false
    // `internal` (not `private`) so `RecipeDetailView+LoadStateChange.swift`
    // (split out for the file-length cap, DUT-1240) can dismiss on `.unavailable`.
    @Environment(\.dismiss) var dismiss
    /// T-804 — drives the iPad reading-column cap in `readyBody`. `.regular`
    /// (iPad) bounds the content below the hero to a centered column;
    /// `.compact` (iPhone) leaves the layout byte-identical. DUT-631 — now
    /// `internal` (not `private`) so `RecipeDetailView+Sections.swift`'s
    /// relocated `ingredientsInstructions(twoUp:)` can read it.
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    public let onSelectRelated: (RecipeListItem) -> Void
    /// DUT-534 — the "View" action on the "Added to your Shopping List"
    /// Snackbar routes here. The App composition root passes a closure that
    /// opens `dod://shopping-list` (switch to Saved + push the list); the
    /// feature package stays free of any App / deep-link import. `nil` (the
    /// default) hides the View action — used by previews / hosts that don't
    /// wire routing.
    public let openShoppingList: (() -> Void)?
    /// DUT-535 — builds the ingredient-selection sheet for the tapped recipe.
    /// The sheet type (``AddToShoppingListSheet``) lives in `DODFeatureSaved`,
    /// which this package must not import, so the App composition root injects a
    /// closure that constructs it (type-erased to `AnyView`). It's handed the
    /// recipe + a completion that reports the append result back so the view
    /// model can surface the confirming Snackbar. `nil` (previews / hosts that
    /// don't wire the list) falls back to the DUT-534 immediate add-all.
    public let addToShoppingListSheet: ((Recipe, @escaping (AddToShoppingListResult) -> Void) -> AnyView)?
    /// T-912 / DUT-551 (CL-306) — the per-recipe Heat Coach nudge's "Open Heat
    /// Coach" tap. The App root passes a closure that selects the Cooking Tools
    /// hub tab and mints a hub token; the feature package stays free of any App /
    /// tab-selection import. `nil` (default) hides the whole nudge (same seam as
    /// `openShoppingList`). DUT-584 — carries an optional ``HeatCoachSeed`` so the
    /// nudge opens the coach pre-answered from the recipe's own heat profile.
    public let openHeatCoach: ((HeatCoachSeed?) -> Void)?
    /// T-912 / DUT-551 (CL-306) — builds the Heat Coach surface presented as a
    /// sheet OVER Cook Mode's full-screen cover. `HeatCoachView` lives in
    /// `DODFeatureFeed` (not importable here), so the App root injects a
    /// type-erased `AnyView` builder, forwarded to `CookModeView`. `nil`
    /// (previews / unwired hosts) hides the Cook Mode shortcut.
    public let heatCoachSheet: (() -> AnyView)?

    /// DUT-1240 — fired when `autoStartCookMode` actually PRESENTS Cook Mode
    /// (data loaded + auto-start consumed), not merely at construction. Lets
    /// the host disarm a "came here to cook" arm once genuinely fulfilled,
    /// rather than on the tap (too early) or the tab switch (too late).
    public let onAutoCookModeStarted: (() -> Void)?

    /// DUT-535 — the recipe whose ingredient-selection sheet is presented.
    /// Non-nil drives the `.sheet(item:)`; set when the toolbar `cart.badge.plus`
    /// is tapped, cleared on dismiss. `internal` (not `private`) so the
    /// `RecipeDetailView+Toolbar.swift` extension can present it.
    @State var recipeForShoppingListSheet: SheetRecipe?

    /// DUT-1324 — the generated recipe PDF whose iOS share sheet is presented.
    /// Non-nil drives the `.sheet(item:)`; set by the toolbar Share button after
    /// the PDF is built. `internal` so the `RecipeDetailView+Toolbar.swift`
    /// extension can set it.
    @State var sharePDF: SharePDFItem?

    public init(
        viewModel: RecipeDetailViewModel,
        onSelectRelated: @escaping (RecipeListItem) -> Void,
        autoStartCookMode: Bool = false,
        openShoppingList: (() -> Void)? = nil,
        addToShoppingListSheet: ((Recipe, @escaping (AddToShoppingListResult) -> Void) -> AnyView)? = nil,
        openHeatCoach: ((HeatCoachSeed?) -> Void)? = nil,
        heatCoachSheet: (() -> AnyView)? = nil,
        onAutoCookModeStarted: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _pendingAutoCookMode = State(initialValue: autoStartCookMode)
        self.onSelectRelated = onSelectRelated
        self.openShoppingList = openShoppingList
        self.addToShoppingListSheet = addToShoppingListSheet
        self.openHeatCoach = openHeatCoach
        self.heatCoachSheet = heatCoachSheet
        self.onAutoCookModeStarted = onAutoCookModeStarted
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            content
            snackbar
        }
        .background(DODColor.surface)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // DUT-572 / CL-312 — full-bleed hero: hide the nav-bar background so the
        // hero photo reaches the top of the screen, and force a dark color
        // scheme so the system chrome (back chevron + our glyphs) renders light
        // over the photo.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .toolbar { toolbarItems }
        // Note: T-302 originally added a sticky `RecipeDetailFloatingActions`
        // overlay anchored to `.bottomTrailing` here. Removed by T-410 /
        // CL-42 — the nav-bar Save + Share (AC-4.7 + AC-4.8) are the
        // single in-recipe affordance for both actions. See US-26 / AC-26.1.
        // Toolbar haptics: Save + Download success ticks; Share light tick (DUT).
        .sensoryFeedback(.success, trigger: viewModel.isSaved)
        .sensoryFeedback(.success, trigger: viewModel.isDownloaded)
        .sensoryFeedback(.impact(weight: .light), trigger: shareTapCount)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.checkedIngredientIDs.count)
        #if os(iOS)
        .fullScreenCover(isPresented: $isCookModePresented) {
            cookModeCover
        }
        #else
        .sheet(isPresented: $isCookModePresented) {
            cookModeCover
        }
        #endif
        // DUT-535 — the ingredient-selection sheet. Presented when the toolbar
        // `cart.badge.plus` is tapped (see `RecipeDetailView+Toolbar.swift`),
        // built by the App-injected `addToShoppingListSheet` closure (the sheet
        // type lives in `DODFeatureSaved`). On the sheet's "Add N items" the
        // completion routes the result to the view model for the Snackbar.
        .sheet(item: $recipeForShoppingListSheet) { wrapper in
            addToShoppingListSheet?(wrapper.recipe) { result in
                viewModel.showAddToShoppingListSnackbar(for: result)
            }
        }
        #if os(iOS)
        // DUT-1324 — the full iOS share sheet over the generated recipe PDF,
        // presented once the toolbar Share button has built the file.
        .sheet(item: $sharePDF) { item in
            ShareSheet(items: [item.pdfURL, LinkActivityItemSource(item.linkURL)])
        }
        #endif
        .task {
            await viewModel.onAppear()
            isOfflineSnapshot = await viewModel.isOffline
        }
        .onChange(of: viewModel.loadState) { _, newValue in
            handleLoadStateChange(newValue)
        }
        // DUT-315 — a recipe swapped in AFTER `.ready` (no loadState transition)
        // must still re-seed the stepper to the new source yield; keyed on the
        // changed yield so it doesn't clobber the user's manual edits.
        .onChange(of: viewModel.recipe?.servings) { _, _ in
            viewModel.resyncServingsIfSourceYieldChanged()
        }
    }

    @ViewBuilder
    private var cookModeCover: some View {
        if let recipe = viewModel.recipe, !recipe.instructions.isEmpty {
            CookModeView(
                recipe: recipe,
                initialCheckedIngredients: viewModel.checkedIngredientIDs,
                ingredientScaleFactor: viewModel.servingsScaleFactor,
                onClose: { updatedChecks in
                    viewModel.mergeIngredientChecks(updatedChecks)
                    isCookModePresented = false
                },
                // DUT-326 — persist a Cook Mode "log this cook" to the journal
                // store. The sheet has already saved the photo + assembled the
                // entry; the VM writes it through the dependency seam.
                onLogCook: { entry in
                    Task { await viewModel.logCook(entry) }
                },
                // T-912 / DUT-551 — forward the Heat Coach sheet builder so a
                // heat-related Cook Mode step can present Heat Coach OVER the
                // cover (a tab switch would be invisible under the full-screen
                // cover). Nil when the host doesn't wire hub routing.
                heatCoachSheet: heatCoachSheet
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loadingDetail:
            loadingSkeleton
        case .unavailable:
            EmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Recipe unavailable",
                message: "This recipe can't be displayed right now."
            )
        // DUT-627 — a transient network failure with no cache. Distinct from
        // `.unavailable` (which auto-pops): keep the user here with a Retry
        // button so a flaky-connection open isn't mistaken for a dead recipe.
        case .retryableError:
            EmptyState(
                systemImage: "wifi.slash",
                title: "Couldn't load recipe",
                message: "Check your connection and try again.",
                action: .init(title: "Retry") {
                    Task { await viewModel.retryLoad() }
                }
            )
        case .ready:
            readyBody
        // US-37 / CL-63 / AC-37.3 (T-640): article rendering branch.
        // Posts that lack parseable JSON-LD but have an extractable HTML
        // body render via `ArticleDetailView` with the carried `Recipe`
        // (kind == .article, populated `articleBodyHTML`).
        case .article(let article):
            ArticleDetailView(recipe: article)
        }
    }

    private var readyBody: some View {
        // T-804 — GeometryReader feeds the actual canvas width so the body can
        // flip Ingredients|Instructions into a two-up band once it's wide
        // enough (landscape iPad / large split). Size classes alone can't tell
        // iPad portrait from landscape (both are `.regular`), so we read width.
        // DUT-572 / CL-312 — also reads the real top safe-area inset here (the
        // full-bleed hero ignores safe area, so it can't read its own) and
        // passes it into `RecipeDetailHero`.
        GeometryReader { geo in
            let twoUp = geo.size.width >= 1000
            let topInset = geo.safeAreaInsets.top
            ScrollViewReader { proxy in
                ScrollView {
                    // DUT-573 / CL-313 + DUT-631 — iterated editorial order:
                    // full-bleed hero → [published date · Jump to Instructions]
                    // row → editorial (cropped blurb) → info card (interactive
                    // Servings) → Heat Coach nudge → video → ingredients → Cook
                    // Mode CTA → instructions → related → ratings. DUT-631 moved
                    // the Cook Mode CTA to sit directly above Instructions so the
                    // "Jump to Instructions" link lands on the CTA.
                    VStack(alignment: .leading, spacing: DODSpacing.lg) {
                        // Hero sits OUTSIDE the reading column — full-bleed, no
                        // horizontal padding.
                        RecipeDetailHero(
                            url: viewModel.recipe?.heroImageLargeURL ?? viewModel.listItem.heroImage,
                            title: viewModel.listItem.title,
                            topInset: topInset
                        )
                        // Top block — capped to the reading column on iPad,
                        // byte-identical on iPhone.
                        VStack(alignment: .leading, spacing: DODSpacing.lg) {
                            // DUT-573 / CL-313 — publish date + Jump to
                            // Instructions link, right under the hero/name.
                            dateAndJumpRow(proxy: proxy)
                            excerptText
                            RecipeInfoCard(
                                model: infoCardModel,
                                servingsBinding: Binding(
                                    get: { viewModel.userServings },
                                    set: { viewModel.setUserServings($0) }
                                ),
                                servingsRange: viewModel.userServingsRange,
                                sourceServings: viewModel.sourceServings,
                                showsServingWarning: viewModel.shouldShowServingWarning
                            )
                            heatCoachNudge
                            if let video = viewModel.recipe?.video {
                                RecipeDetailVideoSection(video: video, isOfflineSnapshot: isOfflineSnapshot)
                            }
                        }
                        .readableContentColumn(horizontalSizeClass)
                        ingredientsInstructions(twoUp: twoUp)
                        // Related + ratings — back in the reading column.
                        VStack(alignment: .leading, spacing: DODSpacing.lg) {
                            RelatedRecipesStrip(
                                items: isOfflineSnapshot ? [] : viewModel.related,
                                onSelect: onSelectRelated
                            )
                            RecipeDetailRatingsSection(viewModel: viewModel)
                        }
                        .readableContentColumn(horizontalSizeClass)
                    }
                    .padding(.bottom, DODSpacing.xl)
                }
                // DUT-572 / CL-312 — named space the stretchy hero reads `minY`
                // from to grow only its top edge on pull-down.
                .coordinateSpace(name: "recipeScroll")
                // DUT-638 — let the scroll content run to the very top of the
                // screen so the hero photo sits UNDER the toolbar (the blur strip
                // is the header). Without this the enclosing GeometryReader keeps
                // the ScrollView below the safe-area top, so the hero started
                // under the nav bar and the brown `DODColor.surface` body
                // background showed as a header band above it. The parent
                // GeometryReader still reports the real `topInset` (it's the one
                // that reads the safe area), so the hero's blur-band height + the
                // extra height it draws into the notch are unchanged.
                .ignoresSafeArea(.container, edges: .top)
            }
        }
    }

    /// DUT-573 / CL-313 — the first row of scrolling content, right under the
    /// hero (the recipe name is overlaid on the hero): the publish date on the
    /// leading edge, a subtle "Jump to Instructions" link on the trailing edge.
    /// The link scrolls to the `.instructions` anchor via the enclosing
    /// `ScrollViewReader`'s proxy. DUT-631 — that anchor now sits on the Cook
    /// Mode CTA that leads the Instructions section, so the jump lands with Cook
    /// Mode at the top of the viewport (Instructions immediately below it).
    private func dateAndJumpRow(proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .firstTextBaseline) {
            PublishedDateCaption(date: viewModel.listItem.publishedAt)
            Spacer(minLength: DODSpacing.sm)
            if !(viewModel.recipe?.instructions.isEmpty ?? true) {
                Button {
                    withAnimation { proxy.scrollTo(SectionAnchor.instructions, anchor: .top) }
                } label: {
                    Text("Jump to Instructions")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.accent)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Jumps to Instructions section")
            }
        }
        .padding(.horizontal, DODSpacing.md)
    }

    // DUT-804 / DUT-631 — the `ingredientsInstructions(twoUp:)` layout helper and
    // the relocated `cookModeCTA` live in `RecipeDetailView+Sections.swift`
    // (extension on `RecipeDetailView`) so this file stays under the SwiftLint
    // file-length cap.

    // DUT-572 / CL-312: the `excerptText` body (now the FULL description) + the
    // `strippingExcerptTruncationTail(from:)` pure helper live in
    // `RecipeDetailView+Blurb.swift` (extension on `RecipeDetailView`) so this
    // file stays under the SwiftLint file-length cap. The description renders
    // through the shared `ArticleBlocksView` (paragraphs, headings, lists, AND
    // inline images).

    // DUT-572 / CL-312 — the `infoCardModel` builder + its `joinedOrNil` and
    // `format(duration:)` helpers live in `RecipeDetailView+InfoCard.swift`
    // (extension on `RecipeDetailView`) so this file stays under the SwiftLint
    // file-length cap.
    //
    // `handleLoadStateChange(_:)` lives in
    // `RecipeDetailView+LoadStateChange.swift` for the same reason.
}
