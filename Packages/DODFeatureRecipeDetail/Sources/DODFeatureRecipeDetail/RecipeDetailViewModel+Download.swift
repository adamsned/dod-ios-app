import DODSupport

/// US-35 — explicit download for offline use. Lives in a separate
/// extension file from `RecipeDetailViewModel.swift` so the main class
/// body stays under SwiftLint's `type_body_length` cap.
extension RecipeDetailViewModel {

    /// AC-35.2..AC-35.4. Routes through the dependency surface which
    /// marks the recipe row as offline-pinned AND downloads the hero
    /// image at full resolution through the existing
    /// `RecipeStore.cacheImage` pin path. Snackbar copy branches on the
    /// dependency's ``DownloadOutcome``: "Recipe downloaded for offline
    /// use" on first-time, "Already downloaded" when the recipe was
    /// previously downloaded OR is currently saved (AC-5.2's
    /// auto-download path has already pinned the bytes per CL-61).
    /// Errors are logged and surfaced as "Couldn't download — try
    /// again." copy.
    public func downloadForOffline() async {
        guard let recipe else { return }
        do {
            let outcome = try await dependencies.downloadForOffline(recipe: recipe)
            isDownloaded = true
            switch outcome {
            case .firstTime:
                snackbarMessage = "Recipe downloaded for offline use"
            case .alreadyDownloaded:
                snackbarMessage = "Already downloaded"
            }
        } catch {
            DODLog.persistence.error("download failed: \(String(describing: error))")
            snackbarMessage = "Couldn't download — try again."
        }
    }
}
