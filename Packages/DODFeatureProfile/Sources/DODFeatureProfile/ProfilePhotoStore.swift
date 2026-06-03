#if canImport(UIKit)
import Foundation
import UIKit

/// Failure modes for reading / writing the on-disk profile photo. Surfaced
/// so the edit view can render a humane prompt instead of a silent drop
/// (matches the ``ProfileStoreError`` shape from Phase a).
public enum ProfilePhotoStoreError: Error, Equatable {

    /// `UIImage.jpegData(compressionQuality:)` returned `nil` (the image
    /// could not be serialized to JPEG — e.g. a `CIImage`-backed UIImage
    /// with no `cgImage`). Treated as a fatal save failure surfaced to
    /// the edit view.
    case encodingFailed

    /// A `FileManager` write / read / delete call threw. Wraps the
    /// underlying error's localized description (we don't keep the
    /// `Error` itself so `Equatable` conformance stays mechanical —
    /// matches the ``ProfileStoreError/keychainFailed(OSStatus)`` shape).
    case ioFailed(String)
}

/// Read / write / clear the on-disk profile photo. Two implementations:
/// ``ProfilePhotoStore`` for production and ``InMemoryProfilePhotoStore``
/// for tests + UI-test injection. The production store writes JPEGs
/// keyed by a UUID-derived filename inside the app's Documents directory;
/// the in-memory store keeps `Data` blobs in a dictionary.
///
/// Async-throws-protocol shape mirrors ``ProfileStoring`` so callers
/// (``ProfileStore``, the edit view) await both stores the same way.
///
/// Spec trace: US-44 AC-44.3, AC-44.8, AC-44.9; CL-137.
public protocol ProfilePhotoStoring: Sendable {

    /// Persists the cropped image as a JPEG inside the app's Documents
    /// directory. Returns the bare filename (no path components) so the
    /// caller can store it in ``UserProfile/photoFilename``.
    func save(_ image: UIImage) async throws -> String

    /// Loads the JPEG bytes for the given filename. Returns `nil` if
    /// the file is missing (graceful degradation — the Keychain still
    /// has the filename but Documents was wiped by the user via Files.app,
    /// or a partial sync from a future cross-device push leaves the row
    /// without its photo).
    func load(filename: String) async -> UIImage?

    /// Deletes the photo file. No-op if missing (matches the
    /// ``ProfileStoring/clear()`` idempotency contract).
    func clear(filename: String) async throws
}

// MARK: - Production implementation

/// Production ``ProfilePhotoStoring`` backed by the app's Documents
/// directory. JPEG at 0.85 quality, square 512×512 output.
///
/// **Storage layout.** `<Documents>/profile-photo-<UUID().uuidString>.jpg`.
/// UUID-keyed (rather than a fixed `profile-photo.jpg`) so Replace cycles
/// are atomic by construction: the edit view writes a new UUID then
/// clears the old file via ``clear(filename:)``, never the reverse, so a
/// mid-flow failure leaves the previous photo intact rather than half-
/// overwritten. Locked per CL-137 alternative (h).
///
/// **Output resolution + quality.** 512×512 covers the 60pt Settings
/// avatar at @3x (180px) with headroom for any larger future surface
/// (a 100pt header or a 256pt full-screen profile view); 0.85 JPEG
/// quality produces ~50–150 KB per photo. Locked per CL-137 decision (3).
///
/// **Thread safety.** Modeled as an `actor` so the disk I/O happens off
/// the main thread, matching the ``KeychainProfileStore`` posture.
/// `FileManager` is safe to call from any thread, and the actor stores
/// no mutable state — every call goes straight to the file system.
public actor ProfilePhotoStore: ProfilePhotoStoring {

    /// Output side length for the JPEG. 512×512 is locked per CL-137.
    static let outputSidePoints: CGFloat = 512

    /// JPEG compression quality. 0.85 is locked per CL-137.
    static let jpegQuality: CGFloat = 0.85

    /// Filename prefix so the row's photo files are easy to spot in
    /// the Documents directory (e.g. for debugging via the iOS Files.app
    /// surface). Locked per CL-137 decision (4).
    static let filenamePrefix = "profile-photo-"

    /// Filename suffix — `.jpg` matches the MIME type the bytes carry.
    static let filenameSuffix = ".jpg"

    /// Used to derive `<Documents>`; defaults to `.default` but injectable
    /// for tests that want to point at a temp directory rather than the
    /// real app sandbox.
    private let fileManager: FileManager
    private let documentsDirectory: URL

    public init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        // `urls(for:in:)` is documented to return at least one URL for
        // `.documentDirectory` on iOS / macOS — but we still guard so a
        // future sandbox change can surface a humane error rather than
        // crash. The throw at init-time is benign — `AppDependencies`
        // can fall back to nil and the photo flow gracefully degrades
        // to the initial-letter avatar.
        guard
            let url = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else {
            throw ProfilePhotoStoreError.ioFailed("Documents directory not available")
        }
        self.documentsDirectory = url
    }

    /// Test-only convenience init that takes the Documents-equivalent URL
    /// directly so the L1 suite can write to a `FileManager`-issued temp
    /// directory without touching the real app sandbox.
    public init(directory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.documentsDirectory = directory
    }

    // MARK: - ProfilePhotoStoring

    public func save(_ image: UIImage) async throws -> String {
        // Normalize to 512×512 via `UIGraphicsImageRenderer` — the crop
        // view hands back an image at whatever size its renderer produced,
        // but the on-disk contract is a square JPEG at the locked output
        // resolution. Renderer scale 1.0 because the 512 is in PIXELS,
        // not points — the avatar surfaces render the JPEG via
        // `Image(uiImage:).resizable()` which scales to the destination
        // frame anyway.
        let target = CGSize(width: Self.outputSidePoints, height: Self.outputSidePoints)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true  // JPEG is opaque; saves one alpha channel
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let jpeg = rendered.jpegData(compressionQuality: Self.jpegQuality) else {
            throw ProfilePhotoStoreError.encodingFailed
        }
        let filename = Self.filenamePrefix + UUID().uuidString + Self.filenameSuffix
        let url = documentsDirectory.appendingPathComponent(filename)
        do {
            // `.atomic` so a crash mid-write leaves the previous file
            // intact (`writeToFile:atomically:` semantics) — though the
            // Replace-Photo flow already uses a fresh UUID per save so
            // the atomic guarantee is belt-and-suspenders.
            try jpeg.write(to: url, options: [.atomic])
        } catch {
            throw ProfilePhotoStoreError.ioFailed(error.localizedDescription)
        }
        return filename
    }

    public func load(filename: String) async -> UIImage? {
        let url = documentsDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    public func clear(filename: String) async throws {
        let url = documentsDirectory.appendingPathComponent(filename)
        // Idempotent — a missing file is success (matches the Keychain
        // `errSecItemNotFound` graceful-degradation contract).
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ProfilePhotoStoreError.ioFailed(error.localizedDescription)
        }
    }
}

// MARK: - In-memory implementation (tests + UI-test injection)

/// In-memory ``ProfilePhotoStoring`` for unit tests + UI-test hosts where
/// touching the real Documents directory would leak state between runs.
/// Modeled as an `actor` so its mutable dictionary state is isolated for
/// the strict-concurrency build, matching ``InMemoryProfileStore``.
public actor InMemoryProfilePhotoStore: ProfilePhotoStoring {

    /// Filename → JPEG bytes. The keys mirror the production filename
    /// shape (`profile-photo-<UUID>.jpg`) so tests that round-trip
    /// through this fake exercise the same naming contract.
    private var stored: [String: Data] = [:]

    /// Records every `clear(filename:)` invocation in arrival order so
    /// the L1 `ProfileStoreTests` integration case can assert
    /// `ProfileStore.clear()` calls through to the photo store.
    public private(set) var clearedFilenames: [String] = []

    public init() {}

    public func save(_ image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: ProfilePhotoStore.jpegQuality) else {
            throw ProfilePhotoStoreError.encodingFailed
        }
        let filename =
            ProfilePhotoStore.filenamePrefix
            + UUID().uuidString
            + ProfilePhotoStore.filenameSuffix
        stored[filename] = data
        return filename
    }

    public func load(filename: String) async -> UIImage? {
        guard let data = stored[filename] else { return nil }
        return UIImage(data: data)
    }

    public func clear(filename: String) async throws {
        clearedFilenames.append(filename)
        stored.removeValue(forKey: filename)
    }
}
#endif
