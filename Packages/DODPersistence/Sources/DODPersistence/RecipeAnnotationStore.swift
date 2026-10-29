import Foundation

/// One persisted handwritten-annotation record for a recipe's instructions
/// (iPad + Apple Pencil feature, DUT — v2).
///
/// The drawing itself is `PKDrawing.dataRepresentation()` bytes, carried here as
/// opaque `Data` so this store — and the whole `DODPersistence` layer — stays
/// Foundation-only. PencilKit is iOS-only; the `PKDrawing` ⇄ `Data` conversion
/// lives in the iOS-guarded view code, never here (same split `CookPhotoStore`
/// uses for `UIImage` ⇄ `Data`).
public struct RecipeAnnotationRecord: Codable, Equatable, Sendable {

    /// `PKDrawing.dataRepresentation()` bytes for the recipe's annotation.
    public var drawingData: Data

    /// The width (points) of the instructions block the drawing was captured
    /// over. Persisted so a later load can note — and, if desired, scale for —
    /// a changed layout width (Dynamic Type, rotation, split view). Anchoring
    /// the canvas to the instructions block (not the whole scroll) keeps the
    /// residual drift small; this value is the escape hatch for what's left.
    public var canvasWidth: Double

    public init(drawingData: Data, canvasWidth: Double) {
        self.drawingData = drawingData
        self.canvasWidth = canvasWidth
    }
}

/// Seam for persisting per-recipe handwritten annotations. Production uses the
/// file-backed ``FileRecipeAnnotationStore``; tests inject
/// ``InMemoryRecipeAnnotationStore``.
public protocol RecipeAnnotationStoring: Sendable {
    /// The saved annotation for a recipe id, or `nil` if none was ever written.
    func annotation(forRecipeID id: Int) -> RecipeAnnotationRecord?
    /// Persist (overwriting) the annotation for a recipe id.
    func save(_ record: RecipeAnnotationRecord, forRecipeID id: Int) throws
    /// Remove any stored annotation for a recipe id (no-op if absent).
    func delete(forRecipeID id: Int)
}

/// File-backed annotation store. One JSON file per recipe under
/// **Application Support/RecipeAnnotations** — *not* Caches, which the OS may
/// purge; an annotation must persist as long as the recipe is on device.
///
/// Mirrors ``CookPhotoStore``: `Data`-based, no UIKit, so it builds on every
/// platform (the macOS `swift test` slice included). Filenames are keyed
/// `dod.annotations.v1.<recipeID>.json`.
public struct FileRecipeAnnotationStore: RecipeAnnotationStoring {

    private let directory: URL

    /// - Parameter directory: override for tests; production uses
    ///   Application Support/RecipeAnnotations.
    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base =
                FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("RecipeAnnotations", isDirectory: true)
        }
    }

    private func fileURL(forRecipeID id: Int) -> URL {
        directory.appendingPathComponent("dod.annotations.v1.\(id).json")
    }

    public func annotation(forRecipeID id: Int) -> RecipeAnnotationRecord? {
        guard let data = try? Data(contentsOf: fileURL(forRecipeID: id)) else { return nil }
        return try? JSONDecoder().decode(RecipeAnnotationRecord.self, from: data)
    }

    public func save(_ record: RecipeAnnotationRecord, forRecipeID id: Int) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(record)
        try data.write(to: fileURL(forRecipeID: id), options: .atomic)
    }

    public func delete(forRecipeID id: Int) {
        try? FileManager.default.removeItem(at: fileURL(forRecipeID: id))
    }
}

/// In-memory fake for unit tests / previews — never touches disk. Thread-safe
/// via an internal lock so it can satisfy the `Sendable` protocol requirement.
public final class InMemoryRecipeAnnotationStore: RecipeAnnotationStoring, @unchecked Sendable {

    private let lock = NSLock()
    private var storage: [Int: RecipeAnnotationRecord] = [:]

    public init(seed: [Int: RecipeAnnotationRecord] = [:]) {
        storage = seed
    }

    public func annotation(forRecipeID id: Int) -> RecipeAnnotationRecord? {
        lock.lock()
        defer { lock.unlock() }
        return storage[id]
    }

    public func save(_ record: RecipeAnnotationRecord, forRecipeID id: Int) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[id] = record
    }

    public func delete(forRecipeID id: Int) {
        lock.lock()
        defer { lock.unlock() }
        storage[id] = nil
    }
}
