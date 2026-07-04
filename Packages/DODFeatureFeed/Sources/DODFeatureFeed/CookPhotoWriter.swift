import DODPersistence
import Foundation

/// DUT-209 — the off-main seam for persisting the First Cookout celebration
/// photo. The "Done" action used to call `CookPhotoStore().save(_:)` — a
/// synchronous `FileManager.createDirectory` + atomic `data.write` flushing
/// full-resolution JPEG bytes — **on the main actor**, right before `dismiss()`.
/// For a multi-MB hero photo that blocked the main thread at the most
/// emotionally important beat of the flow.
///
/// This protocol lets `FirstCookoutView` await the write on a detached
/// (non-main) executor and lets tests assert, via a fake, that the write really
/// does run off the main thread — no timing hack required.
public protocol CookPhotoWriting: Sendable {
    /// Persist `data` under `id`, returning the local filename to store on the
    /// cook entry's `photoLocalID`. Called off the main actor; throws on a disk
    /// failure so the caller can surface the DUT-312 photo-save snackbar.
    func save(_ data: Data, id: String) async throws -> String
}

/// `CookPhotoStore`-backed writer. `CookPhotoStore` is `Sendable` and its
/// `save` is a blocking file write, so this simply performs it off the main
/// actor (the call site hops via `Task.detached`).
public struct SystemCookPhotoWriter: CookPhotoWriting {
    public init() {}

    public func save(_ data: Data, id: String) async throws -> String {
        try CookPhotoStore().save(data, id: id)
    }
}
