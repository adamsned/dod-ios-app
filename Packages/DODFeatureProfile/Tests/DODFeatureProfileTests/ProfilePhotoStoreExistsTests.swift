#if canImport(UIKit)
import Foundation
import Testing
import UIKit

@testable import DODFeatureProfile

/// L1 coverage for T-746 / CL-143's `exists(filename:)` +
/// `existsOriginal(filename:)` additions to ``ProfilePhotoStoring``.
/// Pins the truth table on both the production ``ProfilePhotoStore``
/// (FileManager-backed) and the ``InMemoryProfilePhotoStore`` fake:
/// - Real file → true.
/// - Missing file (stale ref — the DUT-40 reproducer) → false.
/// - Empty string (degenerate defensive short-circuit) → false.
///
/// Tests use a `.temporaryDirectory`-rooted subdirectory so each
/// production-store test gets isolated storage (no cross-test bleed +
/// no real-sandbox writes that would survive between simulator
/// launches). Mirrors the rooting pattern in ``ProfilePhotoStoreTests``.
///
/// Spec trace: US-44 AC-44.8 amendment; CL-143.
@Suite("ProfilePhotoStore exists (T-746)")
struct ProfilePhotoStoreExistsTests {

    // MARK: - Production store

    @Test func existsReturnsTrueForRealFile() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)
        let image = Self.solidColorImage(side: 128, color: .red)

        let filename = try await store.save(image)
        let result = await store.exists(filename: filename)

        #expect(result == true)
    }

    @Test func existsReturnsFalseForMissingFile() async throws {
        // The stale-reference shape from CL-143 (Keychain row persists,
        // Documents wiped). The picker-entry conditional in
        // `handleProfilePictureRowTap` would route to the action sheet
        // if not for the view-mount validation that this method powers.
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)

        let result = await store.exists(filename: "profile-photo-never-saved.jpg")

        #expect(result == false)
    }

    @Test func existsReturnsFalseForEmptyString() async throws {
        // Degenerate-but-safe defensive short-circuit per CL-143 —
        // an empty filename never matches a real file.
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)

        let result = await store.exists(filename: "")

        #expect(result == false)
    }

    @Test func existsOriginalReturnsTrueForRealFile() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)
        let image = Self.solidColorImage(side: 256, color: .blue)

        let filename = try await store.saveOriginal(image)
        let result = await store.existsOriginal(filename: filename)

        #expect(result == true)
    }

    @Test func existsOriginalReturnsFalseForMissingFile() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)

        let result = await store.existsOriginal(
            filename: "profile-photo-original-never-saved.jpg"
        )

        #expect(result == false)
    }

    @Test func existsOriginalReturnsFalseForEmptyString() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)

        let result = await store.existsOriginal(filename: "")

        #expect(result == false)
    }

    // MARK: - In-memory store

    @Test func inMemoryExistsReturnsTrueForRealFile() async throws {
        let store = InMemoryProfilePhotoStore()
        let image = Self.solidColorImage(side: 64, color: .green)

        let filename = try await store.save(image)
        let result = await store.exists(filename: filename)

        #expect(result == true)
    }

    @Test func inMemoryExistsReturnsFalseForMissingFile() async {
        let store = InMemoryProfilePhotoStore()
        let result = await store.exists(filename: "profile-photo-never-saved.jpg")
        #expect(result == false)
    }

    @Test func inMemoryExistsReturnsFalseForEmptyString() async {
        let store = InMemoryProfilePhotoStore()
        let result = await store.exists(filename: "")
        #expect(result == false)
    }

    @Test func inMemoryExistsOriginalReturnsTrueForRealFile() async throws {
        let store = InMemoryProfilePhotoStore()
        let image = Self.solidColorImage(side: 128, color: .yellow)

        let filename = try await store.saveOriginal(image)
        let result = await store.existsOriginal(filename: filename)

        #expect(result == true)
    }

    @Test func inMemoryExistsOriginalReturnsFalseForMissingFile() async {
        let store = InMemoryProfilePhotoStore()
        let result = await store.existsOriginal(
            filename: "profile-photo-original-never-saved.jpg"
        )
        #expect(result == false)
    }

    @Test func inMemoryExistsOriginalReturnsFalseForEmptyString() async {
        let store = InMemoryProfilePhotoStore()
        let result = await store.existsOriginal(filename: "")
        #expect(result == false)
    }

    // MARK: - Helpers

    /// Creates a fresh `.temporaryDirectory`-rooted subdirectory so each
    /// test gets isolated storage. Mirrors the helper in
    /// ``ProfilePhotoStoreTests`` so the existence-check tests don't
    /// depend on that file's internals.
    private static func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfilePhotoStoreExistsTests-" + UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    /// Renders a solid-color square `UIImage` so the test suite doesn't
    /// depend on a bundle resource fixture. Mirrors the helper in
    /// ``ProfilePhotoStoreTests``.
    private static func solidColorImage(side: CGFloat, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        )
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: side, height: side)))
        }
    }
}
#endif
