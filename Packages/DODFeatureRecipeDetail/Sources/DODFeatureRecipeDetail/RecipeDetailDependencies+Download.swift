import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
import Foundation

/// Outcome of an explicit-download tap (US-35 / AC-35.3 / AC-35.4).
/// `firstTime` triggers the "Recipe downloaded for offline use" snackbar;
/// `alreadyDownloaded` triggers the "Already downloaded" snackbar copy when
/// the recipe has previously been explicitly downloaded (`downloadedAt !=
/// nil`). T-761 / CL-158 (DUT-67) — a merely-*saved* recipe is NO LONGER
/// treated as already-downloaded (save and download are decoupled); a
/// re-download still returns `.alreadyDownloaded` only on the real
/// `downloadedAt` pin.
public enum DownloadOutcome: Sendable, Equatable {
    case firstTime
    case alreadyDownloaded
}

extension RecipeDetailDependencies {
    /// Default `false` so existing fakes that don't model the
    /// `downloadedAt` flag keep compiling — only the live wiring + the
    /// US-35 unit tests override this. The view model still calls into
    /// this on `onAppear()`; the false return leaves the button at its
    /// default "Download for offline use" accessibility label.
    public func isDownloaded(id: Int) async throws -> Bool { false }

    /// Default `firstTime` for existing fakes that don't override.
    /// Production overrides on `LiveRecipeDetailDependencies` route
    /// through `RecipeStore.markDownloaded(id:)` + the image-pin path.
    public func downloadForOffline(recipe: Recipe) async throws -> DownloadOutcome {
        .firstTime
    }
}

extension LiveRecipeDetailDependencies {

    public func isDownloaded(id: Int) async throws -> Bool {
        try await store.isDownloaded(id: id)
    }

    /// Explicitly download a recipe for offline use. Marks the row's
    /// `downloadedAt`, routes the hero image bytes through
    /// `RecipeStore.cacheImage(...)` with the pin field set so the image
    /// survives `evictImagesIfNeeded`, AND marks the recipe saved (T-761 /
    /// CL-158 — downloading also saves). Image-fetch failures are swallowed
    /// (logged) — the metadata pin still lands. Idempotent: a re-tap on an
    /// already-downloaded recipe returns `.alreadyDownloaded` without
    /// re-fetching the image (AC-35.4).
    ///
    /// **T-761 / CL-158 (DUT-67).** Save and download are decoupled: a
    /// merely-*saved* recipe (`isSaved == true`, `downloadedAt == nil`) is
    /// NOT treated as already-downloaded anymore — only the explicit
    /// `downloadedAt` pin counts. Conversely, downloading always ensures
    /// the recipe is saved via ``RecipeStore/markSaved(id:)``.
    public func downloadForOffline(recipe: Recipe) async throws -> DownloadOutcome {
        let transitioned = try await store.markDownloaded(id: recipe.id)
        // Download also saves (T-761) — idempotent, so a re-download of an
        // already-saved recipe is a no-op on the save side.
        _ = try await store.markSaved(id: recipe.id)
        guard transitioned else {
            // Already explicitly downloaded — no image re-fetch (AC-35.4).
            return .alreadyDownloaded
        }
        // Hero image (US-35 / AC-35.2). Prefer the large URL, fall back
        // to the small. Failure is logged + swallowed — the metadata
        // pin already landed, so the recipe text is still on-device for
        // offline use; the image fetch is best-effort.
        if let url = recipe.heroImageLargeURL ?? recipe.heroImage {
            do {
                let bytes = try await imageLoader.data(for: url)
                try await store.cacheImage(
                    url: url,
                    bytes: bytes,
                    pinnedToSavedRecipeID: recipe.id
                )
            } catch {
                DODLog.network.error(
                    "download hero image failed: \(String(describing: error))"
                )
            }
        }
        return .firstTime
    }
}
