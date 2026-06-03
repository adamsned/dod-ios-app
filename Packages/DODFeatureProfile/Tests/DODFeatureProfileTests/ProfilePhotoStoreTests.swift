#if canImport(UIKit)
import Foundation
import Testing
import UIKit

@testable import DODFeatureProfile

/// L1 coverage for ``ProfilePhotoStore`` — the production
/// Documents-directory JPG persistence + the ``InMemoryProfilePhotoStore``
/// test fake. Pins the save-then-load round-trip, the clear-removes-the-
/// file contract, the load-of-missing-returns-nil graceful-degradation
/// guarantee, and the save-of-an-oversized-image downsizes-to-512×512
/// output contract.
///
/// All tests run against a `FileManager.default.temporaryDirectory`-rooted
/// production store (so we exercise the real disk-write code path without
/// touching the actual app sandbox) plus the in-memory fake.
///
/// Spec trace: US-44 AC-44.3, AC-44.9; CL-137.
@Suite("ProfilePhotoStore (T-740)")
struct ProfilePhotoStoreTests {

    // MARK: - Round-trip

    @Test func saveThenLoadRoundTrips() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)
        let image = Self.solidColorImage(side: 256, color: .red)

        let filename = try await store.save(image)
        let loaded = await store.load(filename: filename)

        #expect(loaded != nil)
        // Saved file shape matches the documented contract — prefix +
        // UUID + suffix — so a future debugger that pokes at the
        // Documents directory recognises the row.
        #expect(filename.hasPrefix(ProfilePhotoStore.filenamePrefix))
        #expect(filename.hasSuffix(ProfilePhotoStore.filenameSuffix))
        // The on-disk file actually exists (not just an in-memory ref).
        let url = directory.appendingPathComponent(filename)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func savedImageIsResizedTo512Square() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)
        // Hand the store a deliberately-oversized landscape image to
        // ensure the downsize-to-square-512 contract still produces a
        // readable JPEG (don't crash on 4000×3000, don't fail to encode).
        let image = Self.solidColorImage(side: 4_000, color: .blue)

        let filename = try await store.save(image)
        let loaded = await store.load(filename: filename)

        #expect(loaded != nil)
        // Output side is 512 — the renderer produces a fixed-size CGImage.
        // `UIImage.size` is in points but our renderer uses scale 1.0 so
        // size == pixel dimensions.
        let outputSize = loaded?.size ?? .zero
        #expect(outputSize.width == ProfilePhotoStore.outputSidePoints)
        #expect(outputSize.height == ProfilePhotoStore.outputSidePoints)
    }

    // MARK: - Clear semantics

    @Test func clearRemovesTheFile() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)
        let image = Self.solidColorImage(side: 128, color: .green)

        let filename = try await store.save(image)
        let url = directory.appendingPathComponent(filename)
        #expect(FileManager.default.fileExists(atPath: url.path))

        try await store.clear(filename: filename)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let loaded = await store.load(filename: filename)
        #expect(loaded == nil)
    }

    @Test func clearOfMissingFileIsIdempotent() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)

        // Two clears in a row on a never-saved filename should succeed —
        // matches the Keychain `errSecItemNotFound` graceful-degradation
        // contract documented on `ProfileStoring.clear()`.
        try await store.clear(filename: "profile-photo-never-saved.jpg")
        try await store.clear(filename: "profile-photo-never-saved.jpg")
    }

    // MARK: - Graceful degradation

    @Test func loadOfMissingFileReturnsNil() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)

        // Filename the store never wrote — should return nil rather
        // than throw (the renderer in `ProfilePhotoView` is documented
        // to fall back to the initial-letter avatar on nil).
        let loaded = await store.load(filename: "profile-photo-deleted.jpg")
        #expect(loaded == nil)
    }

    // MARK: - In-memory fake

    @Test func inMemoryStoreRoundTrips() async throws {
        let store = InMemoryProfilePhotoStore()
        let image = Self.solidColorImage(side: 128, color: .yellow)

        let filename = try await store.save(image)
        let loaded = await store.load(filename: filename)

        #expect(loaded != nil)
        // Same naming contract as the production store so the fake is a
        // faithful drop-in.
        #expect(filename.hasPrefix(ProfilePhotoStore.filenamePrefix))
        #expect(filename.hasSuffix(ProfilePhotoStore.filenameSuffix))
    }

    @Test func inMemoryStoreRecordsClearedFilenames() async throws {
        // The recorded-clears contract is what the
        // ProfileStoreTests integration case asserts against — pin it
        // here so a future refactor of the fake can't silently break
        // the test surface that downstream tests rely on.
        let store = InMemoryProfilePhotoStore()
        let image = Self.solidColorImage(side: 64, color: .magenta)
        let filename = try await store.save(image)

        try await store.clear(filename: filename)

        let cleared = await store.clearedFilenames
        #expect(cleared == [filename])
    }

    // MARK: - Original surface (T-745 / CL-142)

    @Test func saveOriginalRoundTrips() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)
        let image = Self.solidColorImage(side: 1_024, color: .red)

        let filename = try await store.saveOriginal(image)
        let loaded = await store.loadOriginal(filename: filename)

        #expect(loaded != nil)
        // Filename shape matches the documented contract — distinct
        // prefix so a debugger inspecting the Documents directory
        // can tell the cropped derivative apart from the original.
        #expect(filename.hasPrefix(ProfilePhotoStore.originalFilenamePrefix))
        #expect(filename.hasSuffix(ProfilePhotoStore.filenameSuffix))
        // The on-disk file actually exists (not just an in-memory ref).
        let url = directory.appendingPathComponent(filename)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func saveOriginalDownscalesOversizedImage() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)
        // 4096×4096 source — clearly above the 2048 longest-side cap.
        // Expected output is exactly 2048×2048 (square, scale 0.5).
        let image = Self.solidColorImage(side: 4_096, color: .blue)

        let filename = try await store.saveOriginal(image)
        let loaded = await store.loadOriginal(filename: filename)

        #expect(loaded != nil)
        let outputSize = loaded?.size ?? .zero
        #expect(outputSize.width == ProfilePhotoStore.originalLongestSidePixels)
        #expect(outputSize.height == ProfilePhotoStore.originalLongestSidePixels)
    }

    @Test func saveOriginalPreservesAspectRatioOnPortrait() async throws {
        // Portrait input 3000×4000 → longest side 4000, scale factor
        // 2048/4000 = 0.512 → output 1536×2048 (aspect preserved).
        let portrait = Self.solidColorImage(width: 3_000, height: 4_000, color: .green)

        let rendered = ProfilePhotoStore.downscaledIfNeeded(portrait)

        // The pure helper is what `saveOriginal` calls into — pin the
        // downscale math at the helper layer so the L1 test doesn't
        // depend on the encode/decode round-trip preserving the
        // exact float dimensions (JPEG decompression can introduce
        // ±1 px tolerance — the helper is pixel-exact).
        #expect(rendered.size.width == 1_536)
        #expect(rendered.size.height == 2_048)
    }

    @Test func saveOriginalPreservesAspectRatioOnLandscape() async throws {
        // Landscape input 4000×3000 → longest side 4000, scale factor
        // 2048/4000 = 0.512 → output 2048×1536 (aspect preserved).
        let landscape = Self.solidColorImage(width: 4_000, height: 3_000, color: .purple)

        let rendered = ProfilePhotoStore.downscaledIfNeeded(landscape)

        #expect(rendered.size.width == 2_048)
        #expect(rendered.size.height == 1_536)
    }

    @Test func saveOriginalNoOpWhenInputIsUnderCap() async throws {
        // Input already smaller than 2048 — `downscaledIfNeeded`
        // should pass the image through unchanged (no resize, no
        // alloc). Avoids unnecessary work and quality loss for users
        // who upload small source images.
        let small = Self.solidColorImage(width: 800, height: 600, color: .cyan)

        let rendered = ProfilePhotoStore.downscaledIfNeeded(small)

        #expect(rendered.size.width == 800)
        #expect(rendered.size.height == 600)
    }

    @Test func clearOriginalRemovesTheFile() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)
        let image = Self.solidColorImage(side: 256, color: .yellow)

        let filename = try await store.saveOriginal(image)
        let url = directory.appendingPathComponent(filename)
        #expect(FileManager.default.fileExists(atPath: url.path))

        try await store.clearOriginal(filename: filename)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let loaded = await store.loadOriginal(filename: filename)
        #expect(loaded == nil)
    }

    @Test func clearOriginalOfMissingFileIsIdempotent() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)

        try await store.clearOriginal(filename: "profile-photo-original-never-saved.jpg")
        try await store.clearOriginal(filename: "profile-photo-original-never-saved.jpg")
    }

    @Test func loadOriginalOfMissingFileReturnsNil() async throws {
        let directory = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfilePhotoStore(directory: directory)

        let loaded = await store.loadOriginal(filename: "profile-photo-original-deleted.jpg")
        #expect(loaded == nil)
    }

    @Test func inMemoryStoreOriginalRoundTrips() async throws {
        let store = InMemoryProfilePhotoStore()
        let image = Self.solidColorImage(side: 512, color: .magenta)

        let filename = try await store.saveOriginal(image)
        let loaded = await store.loadOriginal(filename: filename)

        #expect(loaded != nil)
        #expect(filename.hasPrefix(ProfilePhotoStore.originalFilenamePrefix))
        #expect(filename.hasSuffix(ProfilePhotoStore.filenameSuffix))
    }

    @Test func inMemoryStoreRecordsClearedOriginalFilenames() async throws {
        let store = InMemoryProfilePhotoStore()
        let image = Self.solidColorImage(side: 256, color: .orange)
        let filename = try await store.saveOriginal(image)

        try await store.clearOriginal(filename: filename)

        let cleared = await store.clearedOriginalFilenames
        #expect(cleared == [filename])
        // The cropped path's recorder is unaffected — pin that the
        // two recorders are independent so a future regression of
        // "clearOriginal accidentally writes to clearedFilenames"
        // shows up here.
        let croppedCleared = await store.clearedFilenames
        #expect(croppedCleared.isEmpty)
    }

    // MARK: - Helpers

    /// Creates a fresh `.temporaryDirectory`-rooted subdirectory so each
    /// test gets isolated storage — no cross-test bleed and no real-
    /// sandbox writes that would survive between simulator launches.
    static func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfilePhotoStoreTests-" + UUID().uuidString)
        // Created lazily by the production store on first write — but
        // we still need to make it ourselves because the store assumes
        // its `documentsDirectory` already exists (matches the real
        // app sandbox where the Documents directory is created at
        // app-install time).
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    /// Renders a solid-color square `UIImage` so the test suite doesn't
    /// depend on a bundle resource fixture. `side` is in points, scale
    /// is 1.0 so points == pixels.
    static func solidColorImage(side: CGFloat, color: UIColor) -> UIImage {
        solidColorImage(width: side, height: side, color: color)
    }

    /// Renders a solid-color rectangular `UIImage` for the T-745
    /// aspect-ratio-preservation tests on portrait + landscape sources.
    /// Scale 1.0 so points == pixels.
    static func solidColorImage(width: CGFloat, height: CGFloat, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        }
    }
}
#endif
