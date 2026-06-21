import Foundation

/// File-backed store for cook-journal photos (US-48 / DUT-104).
///
/// Keeps the photo BYTES out of SwiftData — storing image blobs in the
/// `@Model` would bloat `default.store` (and, if it ever synced, the CloudKit
/// mirror; that exact mistake caused DUT-35). Instead `CachedCookLogEntry`
/// holds only the lightweight `photoLocalID` (a filename) this store returns.
///
/// Photos live under **Application Support/CookPhotos** — *not* Caches, which
/// the OS may purge; a journal photo must persist as long as its entry does.
/// The API is `Data`-based (no UIKit) so it builds on every platform; the iOS
/// layer converts `UIImage` ⇄ `Data` at the edge.
public struct CookPhotoStore: Sendable {

    private let directory: URL

    /// - Parameter directory: override for tests; production uses
    ///   Application Support/CookPhotos.
    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base =
                FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("CookPhotos", isDirectory: true)
        }
    }

    /// Persist photo bytes; returns the local id (filename) to store on the
    /// cook entry's `photoLocalID`.
    @discardableResult
    public func save(_ data: Data, id: String = UUID().uuidString) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(id).jpg"
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    /// Load photo bytes for a stored id, or nil if the file is gone.
    public func data(forID id: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(id))
    }

    /// Delete a photo file (no-op if it isn't there).
    public func delete(id: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(id))
    }
}
