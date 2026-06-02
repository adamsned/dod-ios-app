import DODPersistence
import DODSupport
import Foundation

// DUT-35: extracted from AppDependencies.swift to keep that file under the
// SwiftLint `file_length` cap once the launch-time synced-saved backfill landed.
extension AppDependencies {

    /// One-time seed of the synced saved-set (`SyncedSavedRecipe`) from any
    /// pre-V5 local saves, so scoping CloudKit sync down to that one model
    /// doesn't leave the Saved tab empty after the update that introduced it.
    /// Guarded by a one-shot `UserDefaults` flag: after it runs, `toggleSaved`
    /// maintains the synced set and the local `isSaved` pin becomes a derived
    /// value, so re-running the seed would risk resurrecting a save the user
    /// removed on another device. On failure the flag stays unset so the next
    /// launch retries. Called once from `bootstrap()`.
    func backfillSyncedSavedIfNeeded() async {
        let key = "dod.cloudkit.didBackfillSyncedSavedV1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try await store.backfillSyncedSaved()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            DODLog.app.error(
                "SyncedSaved backfill failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
