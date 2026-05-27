import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
import Foundation

/// Outcome of an explicit-download tap (US-35 / AC-35.3 / AC-35.4).
/// `firstTime` triggers the "Recipe downloaded for offline use" snackbar;
/// `alreadyDownloaded` triggers the "Already downloaded" snackbar copy
/// when the recipe has either previously been explicitly downloaded
/// (`downloadedAt != nil`) or is currently saved (so AC-5.2's
/// auto-download already pinned the bytes on save).
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
    /// `downloadedAt` and routes the hero image bytes through
    /// `RecipeStore.cacheImage(...)` with the pin field set so the image
    /// survives `evictImagesIfNeeded`. Image-fetch failures are
    /// swallowed (logged) — the metadata pin still lands, and the user
    /// can retry by re-tapping if the snackbar shows on a flaky
    /// connection. Idempotent: a re-tap on an already-downloaded recipe
    /// returns `.alreadyDownloaded` without re-fetching the image
    /// (AC-35.4). When the recipe is currently saved (`isSaved == true`),
    /// the AC-5.2 auto-download has already pinned the image bytes —
    /// returning `.alreadyDownloaded` surfaces the right snackbar copy
    /// per AC-35.3 without redundant work.
    public func downloadForOffline(recipe: Recipe) async throws -> DownloadOutcome {
        // AC-35.3 / AC-35.4: idempotent on either pin path.
        let alreadyExplicitlyDownloaded = try await store.isDownloaded(id: recipe.id)
        let alreadySaved = try await store.isSaved(id: recipe.id)
        if alreadyExplicitlyDownloaded || alreadySaved {
            // Make sure the metadata pin lands even if a saved recipe
            // happened to never carry the explicit-download flag — this
            // ensures `isDownloaded(id:)` flips true so the
            // accessibility-label branch + the local cache stay
            // consistent on the next re-tap and across launches.
            _ = try await store.markDownloaded(id: recipe.id)
            return .alreadyDownloaded
        }
        let transitioned = try await store.markDownloaded(id: recipe.id)
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
        return transitioned ? .firstTime : .alreadyDownloaded
    }
}
