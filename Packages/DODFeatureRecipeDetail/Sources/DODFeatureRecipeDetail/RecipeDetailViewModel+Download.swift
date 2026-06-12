import DODSupport

/// US-35 — explicit download for offline use. Lives in a separate
/// extension file from `RecipeDetailViewModel.swift` so the main class
/// body stays under SwiftLint's `type_body_length` cap.
extension RecipeDetailViewModel {

    /// AC-35.2..AC-35.4. Routes through the dependency surface which marks
    /// the recipe row as offline-pinned, downloads the hero image at full
    /// resolution through `RecipeStore.cacheImage`, AND marks the recipe
    /// saved (T-761 / CL-158 — downloading also saves). Snackbar copy
    /// branches on the ``DownloadOutcome``: "Recipe downloaded for offline
    /// use" on first-time, "Already downloaded" when previously downloaded.
    /// Errors are logged and surfaced as "Couldn't download — try again."
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
                snackbarMessage = "Recipe downloaded for offline use"
            case .alreadyDownloaded:
                snackbarMessage = "Already downloaded"
            }
            await dependencies.publishSavedWidgetSnapshot()
        } catch {
            DODLog.persistence.error("download failed: \(String(describing: error))")
            snackbarMessage = "Couldn't download — try again."
        }
    }
}
