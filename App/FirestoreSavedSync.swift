import DODFeatureProfile
import DODPersistence
import DODSupport
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// Syncs saved recipes with the Android app through Firestore at
/// `users/{uid}/saved/{recipeId}` while the user is signed in to Firebase (the
/// profile's Apple / Google sign-in does that) and the sync switch is on. Same
/// docs and merge rules as Android's `SavedRecipeSync`:
/// - local saves and removals are written through as they happen;
/// - this device's saves are uploaded once per sign-in, not every launch, so a
///   removal made elsewhere while this device was closed isn't undone;
/// - removals from other devices win, and offline-download pins stay per device.
///
/// iCloud keeps syncing the user's Apple devices alongside this; remote changes
/// land in `SyncedSavedRecipe`, so iCloud carries them to the other Apple devices.
final class FirestoreSavedSync: SavedRecipeMirror, @unchecked Sendable {

    /// Posted after remote changes are applied, so the Saved tab re-fetches.
    static let changedNotification = Notification.Name("FirestoreSavedSync.changed")
    private static let mergedUIDKey = "dod.firestore.mergedUID"

    private let store: RecipeStore
    private let lock = NSLock()
    private var activeUID: String?  // guarded by `lock`
    // Main thread only:
    private var listener: ListenerRegistration?
    private var applying: Task<Void, Never>?

    private init(store: RecipeStore) {
        self.store = store
    }

    /// Starts syncing for the life of the process. No-op until Firebase is configured.
    static func start(store: RecipeStore) {
        guard FirebaseApp.app() != nil else { return }
        let sync = FirestoreSavedSync(store: store)
        Task { await store.setSavedMirror(sync) }
        // Auth keeps the listener (and so `sync`) for the life of the process.
        _ = Auth.auth().addStateDidChangeListener { _, user in sync.switchTo(user?.uid) }
        NotificationCenter.default.addObserver(
            forName: FirebaseAccount.willDeleteNotification,
            object: nil,
            queue: .main
        ) { _ in sync.switchTo(nil, keepMerged: true) }
    }

    func saved(_ doc: SavedRecipeDoc) {
        guard let uid = lock.withLock({ activeUID }) else { return }
        Self.collection(uid).document(String(doc.id)).setData(doc.fields)
    }

    func removed(id: Int) {
        guard let uid = lock.withLock({ activeUID }) else { return }
        Self.collection(uid).document(String(id)).delete()
    }

    /// Main thread (Auth and NotificationCenter call back on main).
    private func switchTo(_ uid: String?, keepMerged: Bool = false) {
        let active = RecipeStore.cloudKitSyncOptIn() ? uid : nil
        lock.withLock { activeUID = active }
        listener?.remove()
        listener = nil
        guard let active else {
            if !keepMerged { UserDefaults.standard.removeObject(forKey: Self.mergedUIDKey) }
            return
        }
        let remote = Self.collection(active)
        Task { @MainActor [store] in
            if UserDefaults.standard.string(forKey: Self.mergedUIDKey) != active {
                for doc in (try? await store.savedRecipeDocs()) ?? [] {
                    remote.document(String(doc.id)).setData(doc.fields) { _ in }  // not awaited: offline that waits for the server
                }
                UserDefaults.standard.set(active, forKey: Self.mergedUIDKey)
            }
            // Signed out or switched user while uploading.
            guard lock.withLock({ activeUID }) == active else { return }
            listen(to: remote)
        }
    }

    private func listen(to remote: CollectionReference) {
        listener = remote.addSnapshotListener { [weak self] snapshot, error in
            guard let self, let snapshot else {
                // Like Android: remote updates stop until the next sign-in; local saves keep working.
                DODLog.app.error(
                    "Saved-recipe listener stopped. error=\(String(describing: error), privacy: .public)"
                )
                return
            }
            let changes = snapshot.documentChanges.map {
                (removed: $0.type == .removed, id: Int($0.document.documentID),
                 doc: SavedRecipeDoc(fields: $0.document.data()))
            }
            let previous = applying
            // In order, after the previous snapshot. Echoes of this device's own writes are harmless.
            applying = Task { [store] in
                await previous?.value
                for change in changes {
                    if change.removed {
                        if let id = change.id { try? await store.applyRemoteRemoval(id: id) }
                    } else if let doc = change.doc {
                        try? await store.applyRemoteSaved(doc)
                    }
                }
                NotificationCenter.default.post(name: Self.changedNotification, object: nil)
            }
        }
    }

    private static func collection(_ uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("saved")
    }
}
