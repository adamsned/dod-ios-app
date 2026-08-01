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
                // Save haptic is wired via `.sensoryFeedback(.success, trigger:
                // viewModel.isSaved)` on the body — no manual generator here.
                Button {
                    Task { await viewModel.toggleSaved() }
                } label: {
                    Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                        // DUT-1322 — circular scrim (replaces the old bare
                        // `.foregroundStyle` + `.shadow`) so the glyph reads over
                        // BOTH the full-bleed hero photo AND the plain
                        // `DODColor.surface` once scrolled past it. See
                        // `ToolbarGlyphChip.swift` for the contrast math.
                        .toolbarGlyphChip(foreground: ToolbarGlyphForeground.save(isSaved: viewModel.isSaved))
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
                    presentAddToShoppingList()
                } label: {
                    Image(systemName: "cart.badge.plus")
                        // DUT-1322 — see the Save button above.
                        .toolbarGlyphChip(foreground: ToolbarGlyphForeground.neutral)
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
                    // DUT-1322 — see the Save button above.
                    .toolbarGlyphChip(
                        foreground: ToolbarGlyphForeground.download(isDownloaded: viewModel.isDownloaded)
                    )
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
                        // DUT-1322 — see the Save button above.
                        .toolbarGlyphChip(foreground: ToolbarGlyphForeground.neutral)
                }
                .disabled(viewModel.recipe == nil)
                .accessibilityLabel("Share recipe")
                #else
                // macOS `swift test` slice: no UIKit share sheet — keep a plain
                // URL ShareLink so the toolbar still compiles cross-platform.
                ShareLink(item: viewModel.canonicalURL) {
                    Image(systemName: "square.and.arrow.up")
                        .toolbarGlyphChip(foreground: ToolbarGlyphForeground.neutral)
                }
                .accessibilityLabel("Share recipe")
                #endif
            }
        }
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
            sharePDF = SharePDFItem(url: fileURL)
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
