import DODSupport
import Foundation

/// DUT-326 — Cooking Journal logging for ``RecipeDetailViewModel``.
///
/// Lives in its own file so the core view-model body stays under the SwiftLint
/// `file_length` cap. Cook Mode's Done-card "Add to Cooking Journal" action
/// assembles a ``CookLogEntry`` (photo already persisted to ``CookPhotoStore``,
/// caption attached) and routes it here; this writes it to the journal store
/// via the dependency seam. This records a real completed cook and counts
/// toward rank — intentional (DUT-326).
extension RecipeDetailViewModel {

    /// Persist a completed cook to the Cooking Journal. Best-effort: a store
    /// failure is logged and surfaced via a humane snackbar but never thrown
    /// to the UI, so a disk hiccup can't crash the celebratory moment.
    public func logCook(_ entry: CookLogEntry) async {
        do {
            try await dependencies.logCook(entry)
            snackbarMessage = "Saved to your Cooking Journal."
        } catch {
            DODLog.persistence.error("log cook failed: \(String(describing: error))")
            snackbarMessage = "Couldn't save to your journal. Try again from the journal."
        }
    }
}
