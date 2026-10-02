import DODDesignSystem
import DODDomain
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// The recipe-detail top-bar actions + the bottom Snackbar, split out of
// `RecipeDetailView.swift` to keep that file under the SwiftLint 400-line
// `file_length` + 250-line `type_body_length` caps (DUT-534 added the
// "Add to Shopping List" action + the Snackbar action seam).

extension RecipeDetailView {

    // MARK: - Toolbars

    @ToolbarContentBuilder
    var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: DODSpacing.md) {
                // US-54 / T-932 (AC-54.2) — on-device "Summarize". Shown ONLY
                // when the model is usable right now AND there is cached body
                // text to summarize, so unsupported devices (iOS 17-25, no
                // Apple Intelligence, the simulator) see NO dead control — the
                // button is absent, not disabled. Tapping runs the on-device
                // model over the already-cached body and presents the summary
                // sheet. Covers both the recipe (US-4) and article (US-37)
                // branches because the toolbar is shared across them.
                if viewModel.isSummaryAvailable, !viewModel.summaryBodyText.isEmpty {
                    Button {
                        Task { await viewModel.requestSummary() }
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(DODColor.label)
                            .shadow(color: .black.opacity(0.35), radius: 3)
                    }
                    .accessibilityLabel("Summarize")
                    .accessibilityIdentifier("dod.detail.summary.button")
                }

                // DUT-1340 — the bookmark is now a `Menu` with a `primaryAction`.
                // A plain TAP fires `primaryAction` (save/unsave, unchanged);
                // press-and-hold opens the menu with "Add to Collection", which
                // loads the collections + membership and presents the picker
                // sheet. `Menu`+`primaryAction` is used deliberately instead of
                // `.onLongPressGesture` (unreliable on toolbar items).
                // Save haptic is wired via `.sensoryFeedback(.success, trigger:
                // viewModel.isSaved)` on the body — no manual generator here.
                Menu {
                    Button {
                        presentCollectionPicker()
                    } label: {
                        Label("Add to Collection", systemImage: "folder.badge.plus")
                    }
                    .accessibilityIdentifier("dod.detail.addToCollection.menuItem")
                } label: {
                    Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(viewModel.isSaved ? DODColor.accent : DODColor.label)
                        // v2 animation refresh — clean fill↔outline symbol swap
                        // on save/unsave (Reduce Motion → instant). No bounce here:
                        // on the most-tapped glyph it read as jarring, so Save keeps
                        // just the quiet crossfade.
                        .dodSymbolReplace(reduceMotion: reduceMotion)
                        // DUT-572 / CL-312 — glyph shadow so state colors survive
                        // over the full-bleed hero photo (mirrors the title shadow).
                        .shadow(color: .black.opacity(0.35), radius: 3)
                } primaryAction: {
                    Task { await viewModel.toggleSaved() }
                }
                .accessibilityLabel(viewModel.isSaved ? "Unsave recipe" : "Save recipe")

                // US-39 / DUT-534 / DUT-535 — "Add to Shopping List" from ANY
                // recipe (not just saved). DUT-535: tapping now PRESENTS the
                // ingredient-selection sheet (pick which ingredients to add)
                // rather than adding all immediately. Detail's `recipe` is
                // already loaded (ingredients populated), so no hydration is
                // needed. When the sheet seam isn't wired (previews / terse
                // hosts) it falls back to DUT-534's immediate add-all. Sits
                // between Save (AC-4.7) and Download (AC-35.1).
                Button {
                    addToListTapCount += 1
                    presentAddToShoppingList()
                } label: {
                    Image(systemName: "cart.badge.plus")
                        .foregroundStyle(DODColor.label)
                        // v2 animation refresh — the cart bounces as it "receives"
                        // the tap (the glyph has no state to swap, so a tap counter
                        // drives it).
                        .dodSymbolBounce(on: addToListTapCount, direction: .up, reduceMotion: reduceMotion)
                        .shadow(color: .black.opacity(0.35), radius: 3)
                }
                .disabled(viewModel.recipe == nil)
                .accessibilityLabel("Add to Shopping List")
                .accessibilityIdentifier("dod.detail.addToShoppingList")

                // US-35 / AC-35.1 — explicit download for offline use, now a
                // toggle (T-775 / DUT-81, supersedes CL-61's always-outline +
                // "Already downloaded" re-tap snackbar). Downloaded → filled
                // burnt-orange glyph; tapping removes the download. Not
                // downloaded → outline glyph; tapping downloads. Sits between
                // Save (AC-4.7) and Share (AC-4.8).
                Button {
                    Task { await viewModel.toggleDownload() }
                } label: {
                    Image(
                        systemName: viewModel.isDownloaded
                            ? "square.and.arrow.down.fill"
                            : "square.and.arrow.down"
                    )
                    .foregroundStyle(viewModel.isDownloaded ? DODColor.burntOrange : DODColor.label)
                    // v2 animation refresh — outline↔fill swap on download toggle...
                    .dodSymbolReplace(reduceMotion: reduceMotion)
                    // ...with a DOWNWARD bounce — the arrow "pulls" the recipe
                    // down onto the device.
                    .dodSymbolBounce(on: viewModel.isDownloaded, direction: .down, reduceMotion: reduceMotion)
                    .shadow(color: .black.opacity(0.35), radius: 3)
                }
                .accessibilityLabel(viewModel.isDownloaded ? "Remove download" : "Download for offline use")

                // DUT-1324 — the Share glyph opens the full iOS share sheet with a
                // custom print-ready recipe PDF (see `RecipePDFRenderer`): Print,
                // AirDrop, Messages, Mail, contacts, and any share extension. This
                // replaces the old two-option `Menu` (Share Link / Share as Text).
                // The PDF is built at tap time (it needs the hero image + the
                // on-screen scaled/converted recipe), so a `Button` prepares it and
                // drives a `.sheet` on the body rather than an upfront `ShareLink`.
                #if os(iOS)
                Button {
                    Task { await prepareRecipePDFShare() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DODColor.label)
                        // v2 animation refresh — an upward bounce as the sheet is
                        // summoned, echoing the glyph's own up-arrow. Driven by the
                        // existing `shareTapCount` (also the share haptic trigger).
                        .dodSymbolBounce(on: shareTapCount, direction: .up, reduceMotion: reduceMotion)
                        .shadow(color: .black.opacity(0.35), radius: 3)
                }
                .disabled(viewModel.recipe == nil)
                .accessibilityLabel("Share recipe")
                #else
                // macOS `swift test` slice: no UIKit share sheet — keep a plain
                // URL ShareLink so the toolbar still compiles cross-platform.
                ShareLink(item: viewModel.canonicalURL) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DODColor.label)
                        .shadow(color: .black.opacity(0.35), radius: 3)
                }
                .accessibilityLabel("Share recipe")
                #endif
            }
            // US-54 / T-932 — the summary sheet, driven off the view model's
            // `summary` state (no extra @State on the body, which is already at
            // the SwiftLint length cap). Attached to the toolbar content rather
            // than `RecipeDetailView.body` for the same reason.
            .sheet(isPresented: summaryPresented) {
                SummarySheet(state: viewModel.summary) {
                    viewModel.dismissSummary()
                }
            }
        }
    }

    /// US-54 / T-932 — presents the summary sheet whenever ``summary`` leaves
    /// `.idle`; dismissing it resets the state to `.idle`.
    private var summaryPresented: Binding<Bool> {
        Binding(
            get: { viewModel.summary != .idle },
            set: { presented in
                if !presented {
                    viewModel.dismissSummary()
                }
            }
        )
    }

    // MARK: - Share as PDF (DUT-1324)

    #if os(iOS)
    /// Build the print-ready recipe PDF and present the iOS share sheet over it.
    /// Runs at tap time because it needs the hero image (fetched) and the
    /// on-screen SCALED (+ metric-converted) recipe, matching what's displayed —
    /// the same pipeline "Add to Shopping List" / "Share as Text" used (DUT-639).
    func prepareRecipePDFShare() async {
        guard let recipe = viewModel.recipe else { return }
        shareTapCount += 1  // fires the `.sensoryFeedback` tick on the body
        await viewModel.didShare()

        let heroImage = await Self.loadShareImage(recipe.heroImageLargeURL ?? recipe.heroImage)
        let data = Self.recipePDFData(
            recipe: recipe,
            servingsScaleFactor: viewModel.servingsScaleFactor,
            useMetricUnits: useMetricUnits,
            heroImage: heroImage,
            logo: DODBrandAsset.logoBadge
        )
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.pdfFilename(for: recipe))
        do {
            try data.write(to: fileURL, options: .atomic)
            sharePDF = SharePDFItem(pdfURL: fileURL, linkURL: recipe.canonicalURL)
        } catch {
            // Best-effort: temp dir is writable in practice; if not, no sheet.
        }
    }

    /// Pure PDF bytes for a recipe at the current servings/units. `static` +
    /// view-state-free so it's unit-testable without a live view.
    static func recipePDFData(
        recipe: Recipe,
        servingsScaleFactor: Double,
        useMetricUnits: Bool,
        heroImage: UIImage?,
        logo: UIImage?
    ) -> Data {
        let scaled = RecipeDetailViewModel.scaledRecipe(
            recipe,
            by: servingsScaleFactor,
            useMetric: useMetricUnits
        )
        return RecipePDFRenderer().pdfData(recipe: scaled, heroImage: heroImage, logo: logo)
    }

    /// Fetch the hero image for the PDF. Hits the shared `URLCache` that
    /// `ReliableImage` already populated for the on-screen hero, so it's usually
    /// instant; returns `nil` (header degrades) on any failure.
    static func loadShareImage(_ url: URL?) async -> UIImage? {
        guard let url else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    /// A tidy, share-friendly file name (the recipe slug), so the share sheet
    /// and the recipient see e.g. "dutch-oven-pot-roast.pdf".
    static func pdfFilename(for recipe: Recipe) -> String {
        let base = recipe.slug.isEmpty ? "recipe" : recipe.slug
        return "\(base).pdf"
    }
    #endif

    // MARK: - Add to Shopping List (DUT-535)
    // (see the `View.recipePDFShareSheet` helper at the end of this file)

    /// Handle the `cart.badge.plus` tap. DUT-535 — present the ingredient-
    /// selection sheet for the loaded recipe when the sheet seam is wired
    /// (production). When it isn't (previews / terse hosts that only wired the
    /// DUT-534 immediate-add closure), fall back to the immediate add-all so the
    /// action still works. Guarded on `recipe != nil` (the button is disabled
    /// when nil, but guard defensively).
    private func presentAddToShoppingList() {
        guard let recipe = viewModel.recipe else { return }
        if addToShoppingListSheet != nil {
            // DUT-639 — hand the selection sheet the SCALED (+ metric-converted)
            // recipe so the chosen rows match the displayed ingredient lines.
            let scaled = RecipeDetailViewModel.scaledRecipe(
                recipe,
                by: viewModel.servingsScaleFactor,
                useMetric: useMetricUnits
            )
            recipeForShoppingListSheet = SheetRecipe(recipe: scaled)
        } else {
            Task { await viewModel.addToShoppingList(useMetric: useMetricUnits) }
        }
    }

    // MARK: - Add to Collection (DUT-1340)

    /// Handle the bookmark menu's "Add to Collection" item. Loads the
    /// collections + the recipe's current membership into the view model, THEN
    /// flips the presentation flag so the picker sheet opens pre-populated.
    /// Guarded on `recipe != nil` (the picker acts on the loaded recipe).
    private func presentCollectionPicker() {
        guard viewModel.recipe != nil else { return }
        Task {
            await viewModel.loadCollectionsForPicker()
            showCollectionPicker = true
        }
    }

    // MARK: - Snackbar

    @ViewBuilder
    var snackbar: some View {
        if let message = viewModel.snackbarMessage {
            Snackbar(message: message, action: snackbarAction)
                .id(message)  // DUT-419: a new message restarts the auto-dismiss timer
                .padding(.bottom, DODSpacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    viewModel.dismissSnackbar()
                }
        }
    }

    /// DUT-534 — the optional trailing Snackbar action. Present only when the
    /// view model set ``RecipeDetailViewModel/snackbarActionTitle`` (the
    /// "Add to Shopping List" success toast) AND the host wired
    /// ``openShoppingList``. Tapping it dismisses the toast and routes to the
    /// list.
    private var snackbarAction: Snackbar.Action? {
        guard let title = viewModel.snackbarActionTitle, let openShoppingList else {
            return nil
        }
        return Snackbar.Action(title: title) {
            viewModel.dismissSnackbar()
            openShoppingList()
        }
    }
}

extension View {
    /// DUT-1324 — presents the full iOS share sheet over the generated recipe
    /// PDF (`SharePDFItem`). iOS-only; a no-op on the macOS `swift test` slice.
    /// Lives here (not inline in `RecipeDetailView.body`) to keep that file under
    /// the SwiftLint 400-line cap.
    @ViewBuilder
    func recipePDFShareSheet(_ item: Binding<SharePDFItem?>) -> some View {
        #if os(iOS)
        sheet(item: item) { ShareSheet(items: [$0.pdfURL, LinkActivityItemSource($0.linkURL)]) }
        #else
        self
        #endif
    }

    /// DUT-1340 — presents the self-contained "Add to Collection" picker
    /// (`RecipeCollectionPickerSheet`) over the recipe. Factored out of
    /// `RecipeDetailView.body` to keep that file under the SwiftLint length cap.
    /// The view model supplies the collections + seed selection (loaded by the
    /// menu action) and receives the create + commit callbacks.
    func recipeCollectionPickerSheet(
        isPresented: Binding<Bool>,
        viewModel: RecipeDetailViewModel
    ) -> some View {
        sheet(isPresented: isPresented) {
            RecipeCollectionPickerSheet(
                recipeTitle: viewModel.recipe?.title ?? viewModel.listItem.title,
                collections: viewModel.pickerCollections,
                initialSelection: viewModel.pickerInitialSelection,
                onCreate: { name in await viewModel.createCollectionFromPicker(name: name) },
                onCommit: { ids in
                    Task { await viewModel.commitCollections(ids) }
                }
            )
        }
    }
}
