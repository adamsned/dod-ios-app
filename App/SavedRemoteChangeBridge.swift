import CloudKit
import CoreData
import Foundation

/// Bridges Core Data / CloudKit "the store changed underneath you" events
/// into the `AsyncStream<Void>` that `LiveSavedDependencies.remoteChanges()`
/// hands the Saved view model (DUT-6, the UI-refresh half of CloudKit sync).
///
/// The Saved tab reads through a one-shot `@ModelActor` fetch
/// (`RecipeStore.savedRecipes()`) that only re-runs on appear. When CloudKit
/// imports a recipe saved on another device the on-disk store updates
/// silently, so the displayed list stays stale until the next relaunch. This
/// bridge yields a tick on every remote import; the view model debounces the
/// burst and re-fetches, so the synced recipe appears without a relaunch.
///
/// Two notifications are observed, belt-and-suspenders, because the SwiftData
/// container is opened by the app (no `NSPersistentStoreRemoteChange` opt-out
/// is set, and SwiftData enables remote-change posting for CloudKit-backed
/// configs) but the exact posting behavior under SwiftData is version-
/// sensitive:
///
/// - `Notification.Name.NSPersistentStoreRemoteChange` — the coordinator
///   posts this when CloudKit applies imported changes to the store. This is
///   the canonical "remote data arrived" signal.
/// - `NSPersistentCloudKitContainer.eventChangedNotification`, filtered to a
///   **finished** `.import` event — the same notification
///   ``CloudKitSyncDiagnostics`` already receives (so it is known to fire on
///   device), used as a backstop in case the remote-change post does not
///   surface through SwiftData.
///
/// Both collapse into the same stream; the view model's debounce makes the
/// duplication harmless (one re-fetch per import burst).
///
/// Lives in the App target because only here are CloudKit + Core Data linked;
/// the `DODFeatureSaved` package stays free of those frameworks and receives
/// the abstract stream through the `SavedDependencies` seam.
enum SavedRemoteChangeBridge {

    /// Holds the opaque `NotificationCenter` observer tokens so the
    /// `AsyncStream`'s `@Sendable` `onTermination` closure can deregister them
    /// (the tokens are `any NSObjectProtocol`, which is not `Sendable`, so they
    /// can't be captured directly into that closure). `@unchecked Sendable`:
    /// the tokens are written once at stream construction and only read on
    /// teardown, and `NotificationCenter`'s add/remove are thread-safe.
    private final class ObserverTokens: @unchecked Sendable {
        var tokens: [NSObjectProtocol] = []
    }

    /// Build a fresh `AsyncStream<Void>` wired to both remote-change
    /// notifications. Each subscription registers its own observers and tears
    /// them down when the stream terminates (the view model cancels its
    /// subscription task in `deinit`), so there is no shared mutable state and
    /// the factory is `Sendable`.
    ///
    /// `center` is injectable so a future App-target test could drive it; the
    /// composition root passes `.default`.
    static func makeStream(
        center: NotificationCenter = .default
    ) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let box = ObserverTokens()

            // `NSPersistentStoreRemoteChange`: the coordinator posts this when
            // CloudKit merges imported changes into the store. Yield
            // unconditionally — any remote write is reason to re-fetch.
            box.tokens.append(
                center.addObserver(
                    forName: .NSPersistentStoreRemoteChange,
                    object: nil,
                    queue: .main
                ) { _ in
                    continuation.yield(())
                }
            )

            // `NSPersistentCloudKitContainer.eventChangedNotification`:
            // backstop. Yield only on a FINISHED import so a "started" event
            // or an export doesn't trigger a pointless re-fetch. The Event is
            // not Sendable, so read the two fields synchronously here (the
            // observer runs on `.main`) and never let it escape the closure.
            box.tokens.append(
                center.addObserver(
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
            )

            continuation.onTermination = { _ in
                for token in box.tokens {
                    center.removeObserver(token)
                }
            }
        }
    }
}
