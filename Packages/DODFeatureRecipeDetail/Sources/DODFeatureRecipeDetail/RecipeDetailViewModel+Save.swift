import DODAnalytics
import DODSupport

/// Save / unsave from the recipe detail bookmark. Lives in a separate extension
/// file so `RecipeDetailViewModel.swift` stays under SwiftLint's `file_length` cap.
extension RecipeDetailViewModel {

    public func toggleSaved() async {
        do {
            let nowSaved = try await dependencies.toggleSaved(id: listItem.id)
            isSaved = nowSaved
            if nowSaved {
                await dependencies.sendTelemetry(.recipeSaved(recipeID: listItem.id))
                snackbarMessage = "Saved."  // T-761 / CL-158 — lightweight favorite.
            } else {
                await dependencies.sendTelemetry(.recipeUnsaved(recipeID: listItem.id))
                snackbarMessage = "Removed from saved."
            }
            // Refresh the saved-recipes home-screen widget snapshot so its
            // timeline reflects the new state without waiting for
            // WidgetKit's default 15-minute refresh (US-17 / AC-17.3 +
            // AC-17.6). Fire-and-forget; errors are logged inside the
            // dependency, never thrown.
            await dependencies.publishSavedWidgetSnapshot()
        } catch {
            DODLog.persistence.error("toggle save failed: \(String(describing: error))")
            // The store write never landed, so `isSaved` is left untouched; say
            // so rather than leave the tap with no feedback (mirrors `+Download`).
            snackbarMessage =
                isSaved
                ? "Couldn't remove from saved. Try again."
                : "Couldn't save recipe. Try again."
        }
    }
}
