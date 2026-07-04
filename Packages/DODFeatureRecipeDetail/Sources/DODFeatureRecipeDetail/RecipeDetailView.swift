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

    private enum SectionAnchor: Hashable {
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
    // extension can read `viewModel` + `isBlurbExpanded` to render the
    // expand/collapse blurb surface (Swift extensions don't see
    // `private`/`fileprivate` declarations from a sibling file).
    @State var viewModel: RecipeDetailViewModel
    @State private var isOfflineSnapshot: Bool = false
    @State private var isCookModePresented: Bool = false
    /// True when the screen was entered via the StartCookModeIntent deep
    /// link (US-10). We watch the load state and flip the cover open as
    /// soon as the recipe has instructions to render. Resets to false
    /// after firing so a manual exit + re-entry behaves normally.
    @State private var pendingAutoCookMode: Bool
    /// T-732 / CL-129 / AC-4.12: expand-collapse state for the recipe blurb.
    /// Default collapsed (`false`); tapping "More" flips to `true` with a
    /// `withAnimation` transition; tapping "Less" flips back. View-local
    /// state — collapsing does not persist across screen re-entries (matches
    /// the AC-4.2 ingredient check lifetime contract: view-lifetime state).
    @State var isBlurbExpanded: Bool = false
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
    @Environment(\.dismiss) private var dismiss
    /// T-804 — drives the iPad reading-column cap in `readyBody`. `.regular`
    /// (iPad) bounds the content below the hero to a centered column;
    /// `.compact` (iPhone) leaves the layout byte-identical.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// DUT-529 — when Reduce Motion is on, the blurb More/Less expand/collapse
    /// (in `RecipeDetailView+Blurb.swift`) skips its animation (constitution §7).
    /// `internal` (not `private`) so the `+Blurb` extension can read it.
    @Environment(\.accessibilityReduceMotion) var reduceMotion
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

    /// DUT-535 — the recipe whose ingredient-selection sheet is presented.
    /// Non-nil drives the `.sheet(item:)`; set when the toolbar `cart.badge.plus`
    /// is tapped, cleared on dismiss. `internal` (not `private`) so the
    /// `RecipeDetailView+Toolbar.swift` extension can present it.
    @State var recipeForShoppingListSheet: SheetRecipe?

    public init(
        viewModel: RecipeDetailViewModel,
        onSelectRelated: @escaping (RecipeListItem) -> Void,
        autoStartCookMode: Bool = false,
        openShoppingList: (() -> Void)? = nil,
        addToShoppingListSheet: ((Recipe, @escaping (AddToShoppingListResult) -> Void) -> AnyView)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _pendingAutoCookMode = State(initialValue: autoStartCookMode)
        self.onSelectRelated = onSelectRelated
        self.openShoppingList = openShoppingList
        self.addToShoppingListSheet = addToShoppingListSheet
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            content
            snackbar
        }
        .background(DODColor.surface)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarItems }
        // Note: T-302 originally added a sticky `RecipeDetailFloatingActions`
        // overlay anchored to `.bottomTrailing` here. Removed by T-410 /
        // CL-42 — the nav-bar Save + Share (AC-4.7 + AC-4.8) are the
        // single in-recipe affordance for both actions. See US-26 / AC-26.1.
        .sensoryFeedback(.success, trigger: viewModel.isSaved)
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
        // DUT-84 — offline guard on the toolbar download toggle's remove path.
        .modifier(OfflineRemoveDownloadWarningModifier(viewModel: viewModel))
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
                }
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
        GeometryReader { geo in
            let twoUp = geo.size.width >= 1000
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DODSpacing.lg) {
                        RecipeDetailHero(
                            url: viewModel.recipe?.heroImageLargeURL ?? viewModel.listItem.heroImage,
                            title: viewModel.listItem.title
                        )
                        // Top block — capped to the reading column on iPad,
                        // byte-identical on iPhone. T-803 keeps the published
                        // date inset directly below the hero.
                        VStack(alignment: .leading, spacing: DODSpacing.lg) {
                            PublishedDateCaption(date: viewModel.listItem.publishedAt)
                                .padding(.horizontal, DODSpacing.md)
                            RecipeDetailMetaPills(items: metaPillItems)
                            servingsScaler
                            cookNowSection
                            excerptText
                            RecipeDetailQuickJump(items: quickJumpItems(proxy: proxy))
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
            }
        }
    }

    /// Ingredients + Instructions. Side by side in a wider centered band on a
    /// wide canvas (landscape iPad), stacked in the reading column otherwise.
    /// iPhone (compact) always stacks — byte-identical. T-804.
    @ViewBuilder
    private func ingredientsInstructions(twoUp: Bool) -> some View {
        if twoUp {
            HStack(alignment: .top, spacing: DODSpacing.lg) {
                ingredientsSection
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .id(SectionAnchor.ingredients)
                instructionsSection
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .id(SectionAnchor.instructions)
            }
            .frame(maxWidth: DODContentWidth.wide)
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: DODSpacing.lg) {
                ingredientsSection.id(SectionAnchor.ingredients)
                instructionsSection.id(SectionAnchor.instructions)
            }
            .readableContentColumn(horizontalSizeClass)
        }
    }

    /// Per-render serving-count scaler. US-31 / AC-31.1.
    private var servingsScaler: some View {
        RecipeServingsScaler(
            value: Binding(
                get: { viewModel.userServings },
                set: { viewModel.setUserServings($0) }
            ),
            range: viewModel.userServingsRange,
            sourceServings: viewModel.sourceServings,
            showsWarning: viewModel.shouldShowServingWarning
        )
    }

    // T-732 / CL-129 / AC-4.12: the `excerptText` body + the
    // `strippingExcerptTruncationTail(from:)` pure helper + the
    // `recognizedTruncationTails` table live in
    // `RecipeDetailView+Blurb.swift` (extension on `RecipeDetailView`) so
    // this file stays under the SwiftLint file-length cap. The expanded
    // blurb's rich-block rendering goes through the shared
    // `ArticleBlocksView` (in `ArticleBlocksView.swift`) so articles and
    // recipes use the same per-block styling.

    /// AC-7.1 CTA. Hidden until the recipe detail has parsed instructions
    /// — without those, Cook Mode would open onto an empty step list.
    @ViewBuilder
    private var cookNowSection: some View {
        if let recipe = viewModel.recipe, !recipe.instructions.isEmpty {
            CookNowCTA(onTap: {
                Task { await viewModel.didTapCookMode() }
                isCookModePresented = true
            })
        }
    }

    private var metaPillItems: [RecipeDetailMetaPills.Item] {
        // T-732 / CL-129: the servings mini-chip is removed — the
        // `RecipeServingsScaler` row (AC-31.1) directly below the meta pills
        // is the single Serves indicator on the screen. The pre-T-732 chip
        // ("\(servings) servings") duplicated the stepper's canonical
        // "Serves \(userServings)" / "Recipe makes N." display.
        var result: [RecipeDetailMetaPills.Item] = []
        if let total = viewModel.recipe?.totalTime {
            result.append(.init(icon: "clock", label: format(duration: total)))
        }
        return result
    }

    private func quickJumpItems(proxy: ScrollViewProxy) -> [RecipeDetailQuickJump.Item] {
        [
            .init(title: "Ingredients") {
                withAnimation { proxy.scrollTo(SectionAnchor.ingredients, anchor: .top) }
            },
            .init(title: "Instructions") {
                withAnimation { proxy.scrollTo(SectionAnchor.instructions, anchor: .top) }
            },
        ]
    }
}

// MARK: - Helpers

extension RecipeDetailView {

    fileprivate func handleLoadStateChange(_ newValue: RecipeDetailViewModel.LoadState) {
        if newValue == .unavailable {
            // Pop after a brief moment so the snackbar is visible.
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            }
        }
        // US-31 / AC-31.3: once the recipe is loaded, sync the stepper
        // default to the source `recipeYield` if we haven't already.
        if newValue == .ready {
            viewModel.resetServingsToSourceIfFirstLoad()
        }
        // US-10 / AC-10.1: if the deep link asked us to jump straight to
        // Cook Mode, do it the instant the recipe has instructions
        // populated. Same gating as the manual CTA (AC-7.1).
        guard newValue == .ready, pendingAutoCookMode else { return }
        guard let recipe = viewModel.recipe, !recipe.instructions.isEmpty else { return }
        pendingAutoCookMode = false
        Task { await viewModel.didTapCookMode() }
        isCookModePresented = true
    }

    fileprivate func format(duration: Duration) -> String {
        let seconds = Int(duration.components.seconds)
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours)h \(remainder)m"
    }
}
