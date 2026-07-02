import CoreData
import DODPersistence
import DODSupport
import Foundation

// DUT-35: extracted from AppDependencies.swift to keep that file under the
// SwiftLint `file_length` cap once the launch-time synced-saved backfill landed.
extension AppDependencies {

    /// One-time seed of the synced saved-set (`SyncedSavedRecipe`) from any
    /// pre-V5 local saves, so scoping CloudKit sync down to that one model
    /// doesn't leave the Saved tab empty after the update that introduced it.
    ///
    /// DUT-240 — the seed must NOT run against an un-synced store when the
    /// CloudKit mirror is live: a cross-device UNSAVE is expressed as row
    /// ABSENCE in the remote set, so seeding from stale local `isSaved` pins
    /// before the first import lands re-inserts the row and pushes the save
    /// back up to every device. Three paths:
    /// - sync opted OUT → seed immediately (no remote set can conflict; if the
    ///   user opts in later, sync starts from the seeded set).
    /// - sync ON, container open → defer (off the bootstrap path) until the
    ///   first FINISHED CloudKit import, then reconcile: a non-empty imported
    ///   set means another ≥V5 device already owns the live set — its absence
    ///   of an id IS the user's unsave, so skip seeding entirely. An empty
    ///   imported set means this is the user's first ≥V5 device → seed.
    /// - sync ON but the container failed to open (local fallback) → skip this
    ///   launch entirely; anything seeded now would sync up when the mirror
    ///   engages later, reopening the resurrection hole. Self-heals next launch.
    ///
    /// The one-shot `UserDefaults` flag is set only after a seed/reconcile
    /// actually completes, so every skipped/timed-out launch retries.
    func backfillSyncedSavedIfNeeded() async {
        let key = "dod.cloudkit.didBackfillSyncedSavedV1"
        guard !UserDefaults.standard.bool(forKey: key) else {
            // Already migrated on a prior launch — tell the store so mergeDetail
            // reconciles `isSaved` against the synced set authoritatively (DUT-302).
            await store.markSyncedSavedBackfillComplete()
            return
        }
        guard RecipeStore.cloudKitSyncOptIn() else {
            await seedSyncedSaved(flagKey: key)
            return
        }
        guard !usedCloudKitFallback else { return }  // DUT-240: retry next launch
        // DUT-240: don't block bootstrap on the import wait — first-run prompt
        // and deep-link drains run right after it.
        Task { await backfillAfterFirstCloudKitImport(flagKey: key) }
    }

    /// DUT-240 — wait for the first finished CloudKit import (bounded), then
    /// reconcile-or-seed. A timeout leaves the flag unset so the next launch
    /// retries with (hopefully) a live mirror.
    private func backfillAfterFirstCloudKitImport(flagKey: String) async {
        guard await Self.waitForFirstFinishedImport(timeoutSeconds: 20) else { return }
        let remoteSetIsLive = (try? await store.hasAnySyncedSaved()) ?? false
        if remoteSetIsLive {
            // Another ≥V5 device already seeded the shared set; a local pin with
            // no synced row is a cross-device unsave, not a legacy save. Mark
            // complete so mergeDetail reconciles the stale pins DOWN (DUT-302).
            UserDefaults.standard.set(true, forKey: flagKey)
            await store.markSyncedSavedBackfillComplete()
            return
        }
        await seedSyncedSaved(flagKey: flagKey)
    }

    /// The original DUT-35 seed. On failure the flag stays unset so the next
    /// launch retries.
    private func seedSyncedSaved(flagKey: String) async {
        do {
            try await store.backfillSyncedSaved()
            UserDefaults.standard.set(true, forKey: flagKey)
            // DUT-302: only now is the synced set authoritative — let mergeDetail
            // clear stale pins from here on (before this, legacy pins are preserved
            // so opening a recipe pre-backfill can't lose an upgrader's save).
            await store.markSyncedSavedBackfillComplete()
        } catch {
            DODLog.app.error(
                "SyncedSaved backfill failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// DUT-240 — suspend until `NSPersistentCloudKitContainer` posts a FINISHED
    /// `.import` event (the precise "remote state has landed" signal — the
    /// broader `NSPersistentStoreRemoteChange` can fire for local writes too),
    /// or until the timeout. Returns whether an import was observed.
    nonisolated static func waitForFirstFinishedImport(
        timeoutSeconds: UInt64,
        center: NotificationCenter = .default
    ) async -> Bool {
        let stream = AsyncStream<Void> { continuation in
            let token = center.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: nil,
                queue: .main
            ) { note in
                guard
                    let event = note.userInfo?[
                        NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                    ] as? NSPersistentCloudKitContainer.Event,
                    event.type == .import,
                    event.endDate != nil
                else { return }
                continuation.yield(())
            }
            continuation.onTermination = { _ in center.removeObserver(token) }
        }
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in stream { return true }
                return false
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }
}
