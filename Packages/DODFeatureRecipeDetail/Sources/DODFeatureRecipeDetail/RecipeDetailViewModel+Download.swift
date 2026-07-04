import DODSupport

/// US-35 — explicit download for offline use. Lives in a separate
/// extension file from `RecipeDetailViewModel.swift` so the main class
/// body stays under SwiftLint's `type_body_length` cap.
extension RecipeDetailViewModel {

    /// AC-35.2..AC-35.4. Routes through the dependency surface which marks
    /// the recipe row as offline-pinned, downloads the hero image at full
    /// resolution through `RecipeStore.cacheImage`, AND marks the recipe
    /// saved (T-761 / CL-158 — downloading also saves). First-time snackbar
    /// copy names the content kind (T-785 / CL-181): "Article downloaded for
    /// offline use" for an article, else "Recipe downloaded for offline use";
    /// "Already downloaded" when previously downloaded. Errors are logged and
    /// surfaced as "Couldn't download — try again."
    public func downloadForOffline() async {
        guard let recipe else { return }
        do {
            let outcome = try await dependencies.downloadForOffline(recipe: recipe)
            isDownloaded = true
            // T-761 / CL-158 — downloading also saves, so reflect the
            // filled bookmark + refresh the saved-recipes widget snapshot.
            isSaved = true
            switch outcome {
            case .firstTime:
                // T-785 / CL-181 (DUT-91) — name the content type so an
                // article isn't called a "recipe". Recipes stay unchanged.
                let kindWord = recipe.isArticle ? "Article" : "Recipe"
                snackbarMessage = "\(kindWord) downloaded for offline use"
            case .alreadyDownloaded:
                snackbarMessage = "Already downloaded"
            }
            await dependencies.publishSavedWidgetSnapshot()
        } catch {
            DODLog.persistence.error("download failed: \(String(describing: error))")
            snackbarMessage = "Couldn't download — try again."
        }
    }

    /// AC-35.x (T-775 / DUT-81) — inverse of ``downloadForOffline()``. Clears
    /// the explicit-download pin (the recipe stays saved, so the bookmark +
    /// saved-widget snapshot are untouched) and flips the toolbar button back
    /// to its outline state. Errors are logged + surfaced as a retry snackbar.
    public func removeDownload() async {
        guard let recipe else { return }
        do {
            try await dependencies.removeDownload(id: recipe.id)
            isDownloaded = false
            snackbarMessage = "Download removed"
        } catch {
            DODLog.persistence.error("remove download failed: \(String(describing: error))")
            snackbarMessage = "Couldn't remove download — try again."
        }
    }

    /// T-775 / DUT-81 — the toolbar download button's single entry point:
    /// removes the download when the recipe is already downloaded, otherwise
    /// downloads. Keeps the toolbar closure declarative (no branching in the
    /// view).
    ///
    /// DUT-229 — removal is instant whether online OR offline. The old DUT-84
    /// offline confirmation guarded a non-existent risk: `removeDownload` only
    /// clears the `downloadedAt` pin — it deletes NO recipe text and (by design)
    /// leaves the hero image pinned while the recipe stays saved, so the recipe
    /// still opens fine offline. Nothing is stranded, so there is nothing to
    /// warn about; re-downloading is a tap away either way.
    public func toggleDownload() async {
        guard isDownloaded else {
            await downloadForOffline()
            return
        }
        await removeDownload()
    }

    /// Whether the device is currently offline. Drives the detail screen's
    /// offline snapshot (`RecipeDetailView`); grouped here with the rest of the
    /// connectivity-aware download logic (relocated from the main class body in
    /// DUT-84 to keep `RecipeDetailViewModel.swift` under the file-length cap).
    public var isOffline: Bool {
        get async { await !dependencies.isOnline() }
    }
}
