import Foundation
import Testing

@testable import DODSupport

/// Round-trip tests for the image bridge that lets the home-screen widget
/// extensions render real recipe hero images without a network fetch
/// (spec.md US-21 / AC-21.2..AC-21.4, CL-35). The bridge owns:
///
///   - The filename derivation (deterministic for a given URL, stable
///     across launches and across processes).
///   - The file write / delete entry points the host calls from
///     ``RecipeStore.cacheImage(url:bytes:...)`` and ``evictImagesIfNeeded()``.
///   - The `file://` URL resolution the widget hands to `AsyncImage`.
///
/// These tests use a *temporary directory* as a stand-in for the App
/// Group container — the bridge's public API takes an
/// `appGroupIdentifier` so unit tests can avoid touching the real shared
/// container. We can't unit-test against the real App Group because the
/// `containerURL(forSecurityApplicationGroupIdentifier:)` call returns
/// nil in a vanilla simulator slice (no entitlement), and provisioning
/// the entitlement from a Swift Package Manager target isn't possible.
/// Instead each test passes a fresh per-test suite name and the bridge
/// returns nil — we then exercise the pure path (filename derivation) +
/// the file path with a hand-built directory and assert against it.
@Suite("WidgetImageBridge") struct WidgetImageBridgeTests {

    // MARK: - filename(for:) — pure, no I/O

    @Test func filenameIsDeterministicForTheSameURL() throws {
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/hero.jpg"))
        let first = WidgetImageBridge.filename(for: url)
        let second = WidgetImageBridge.filename(for: url)
        #expect(first == second)
    }

    @Test func filenameDiffersForDifferentURLs() throws {
        let urlA = try #require(URL(string: "https://www.dutchovendaddy.com/a.jpg"))
        let urlB = try #require(URL(string: "https://www.dutchovendaddy.com/b.jpg"))
        #expect(WidgetImageBridge.filename(for: urlA) != WidgetImageBridge.filename(for: urlB))
    }

    @Test func filenameUsesImgExtension() throws {
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/hero.png"))
        let filename = WidgetImageBridge.filename(for: url)
        #expect(filename.hasSuffix(".\(WidgetImageBridge.imageFilenameExtension)"))
        #expect(filename.hasSuffix(".img"))
    }

    @Test func filenameIs64HexCharsPlusExtension() throws {
        // SHA256 hex digest = 64 chars; ".img" = 4. Total = 68.
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/hero.jpg"))
        let filename = WidgetImageBridge.filename(for: url)
        #expect(filename.count == 68)
        let hex = filename.dropLast(".img".count)
        #expect(hex.allSatisfy { $0.isHexDigit })
    }

    @Test func filenameDiffersWhenQueryStringDiffers() throws {
        // URL strings drive the hash, so `?w=300` and `?w=600` derivatives
        // get distinct filenames — matches how the host's `CachedImage`
        // table keys by URL.
        let small = try #require(URL(string: "https://example.com/img.jpg?w=300"))
        let large = try #require(URL(string: "https://example.com/img.jpg?w=600"))
        #expect(WidgetImageBridge.filename(for: small) != WidgetImageBridge.filename(for: large))
    }

    // MARK: - fileURL(forFilename:appGroupIdentifier:)
    //
    // `containerURL(forSecurityApplicationGroupIdentifier:)` actually
    // returns a URL even for non-entitled group identifiers on macOS
    // (it just resolves to `~/Library/Group Containers/<id>/`). That's
    // why these tests use real per-test sandbox directories rather than
    // trying to assert nil for a missing entitlement — the goal of the
    // tests is to lock the filename derivation + write/delete round-trip
    // behavior, not to verify Apple's entitlement enforcement.

    @Test func fileURLReturnsContainerPlusSubdirectoryPlusFilename() throws {
        let identifier = "dod.test.bridge.\(UUID().uuidString)"
        // Resolve once to get the container so we can clean up afterward.
        let resolved = try #require(
            WidgetImageBridge.fileURL(forFilename: "abc.img", appGroupIdentifier: identifier)
        )
        #expect(resolved.lastPathComponent == "abc.img")
        let parent = resolved.deletingLastPathComponent()
        #expect(parent.lastPathComponent == WidgetImageBridge.imageSubdirectory)
        // Cleanup the directory the test side-effect created.
        try? FileManager.default.removeItem(at: parent.deletingLastPathComponent())
    }

    // MARK: - writeImage / deleteImage round-trip

    @Test func writeThenReadRoundTripsExactBytes() throws {
        let identifier = "dod.test.bridge.\(UUID().uuidString)"
        defer { Self.cleanupContainer(identifier: identifier) }
        let url = try #require(URL(string: "https://example.com/round-trip.jpg"))
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])  // JPEG-ish

        let didWrite = WidgetImageBridge.writeImage(
            bytes: bytes,
            for: url,
            appGroupIdentifier: identifier
        )
        #expect(didWrite)

        // Resolve the file URL the widget extension would also resolve.
        let fileURL = try #require(
            WidgetImageBridge.fileURL(
                forFilename: WidgetImageBridge.filename(for: url),
                appGroupIdentifier: identifier
            )
        )
        let readBack = try Data(contentsOf: fileURL)
        #expect(readBack == bytes)
    }

    @Test func writeAtomicallyOverwritesExistingFile() throws {
        let identifier = "dod.test.bridge.\(UUID().uuidString)"
        defer { Self.cleanupContainer(identifier: identifier) }
        let url = try #require(URL(string: "https://example.com/overwrite.jpg"))

        let firstBytes = Data([0x01, 0x02, 0x03])
        let secondBytes = Data([0xFE, 0xFD, 0xFC, 0xFB])
        _ = WidgetImageBridge.writeImage(bytes: firstBytes, for: url, appGroupIdentifier: identifier)
        _ = WidgetImageBridge.writeImage(bytes: secondBytes, for: url, appGroupIdentifier: identifier)

        let fileURL = try #require(
            WidgetImageBridge.fileURL(
                forFilename: WidgetImageBridge.filename(for: url),
                appGroupIdentifier: identifier
            )
        )
        #expect(try Data(contentsOf: fileURL) == secondBytes)
    }

    @Test func deleteRemovesPersistedFile() throws {
        let identifier = "dod.test.bridge.\(UUID().uuidString)"
        defer { Self.cleanupContainer(identifier: identifier) }
        let url = try #require(URL(string: "https://example.com/delete.jpg"))
        _ = WidgetImageBridge.writeImage(
            bytes: Data([0xCA, 0xFE]),
            for: url,
            appGroupIdentifier: identifier
        )

        let fileURL = try #require(
            WidgetImageBridge.fileURL(
                forFilename: WidgetImageBridge.filename(for: url),
                appGroupIdentifier: identifier
            )
        )
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let didDelete = WidgetImageBridge.deleteImage(for: url, appGroupIdentifier: identifier)
        #expect(didDelete)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func deleteOfMissingFileReturnsTrue() throws {
        // The widget bridge treats "already gone" as the desired end
        // state — the host's `evictImagesIfNeeded()` calls delete
        // unconditionally even when a previous eviction or external
        // cleanup may have already removed the file. Returning true
        // here keeps the host call-site free of "did the file exist?"
        // branching.
        let identifier = "dod.test.bridge.\(UUID().uuidString)"
        defer { Self.cleanupContainer(identifier: identifier) }
        let url = try #require(URL(string: "https://example.com/never-written.jpg"))
        // Touch the container to make sure the subdirectory exists so the
        // delete path isn't short-circuited by the directory being
        // absent.
        _ = WidgetImageBridge.imageDirectoryURL(appGroupIdentifier: identifier)
        let result = WidgetImageBridge.deleteImage(for: url, appGroupIdentifier: identifier)
        #expect(result)
    }

    @Test func writeAndDeleteUseTheSameFilename() throws {
        // The implicit contract: whatever filename `writeImage` lays
        // down at, `deleteImage` removes from the same path. Lock that
        // by composing the two against a single URL — if a future
        // refactor breaks the symmetry, this test fails before any
        // user notices a stale image in their widget cache.
        let identifier = "dod.test.bridge.\(UUID().uuidString)"
        defer { Self.cleanupContainer(identifier: identifier) }
        let url = try #require(URL(string: "https://example.com/symmetry.jpg"))
        _ = WidgetImageBridge.writeImage(
            bytes: Data([0xAA]),
            for: url,
            appGroupIdentifier: identifier
        )
        let fileURL = try #require(
            WidgetImageBridge.fileURL(
                forFilename: WidgetImageBridge.filename(for: url),
                appGroupIdentifier: identifier
            )
        )
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        _ = WidgetImageBridge.deleteImage(for: url, appGroupIdentifier: identifier)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func imageDirectoryURLCreatesDirectoryIfMissing() throws {
        let identifier = "dod.test.bridge.\(UUID().uuidString)"
        defer { Self.cleanupContainer(identifier: identifier) }
        let directory = try #require(
            WidgetImageBridge.imageDirectoryURL(appGroupIdentifier: identifier)
        )
        #expect(FileManager.default.fileExists(atPath: directory.path))
        #expect(directory.lastPathComponent == WidgetImageBridge.imageSubdirectory)
    }

    @Test func imageSubdirectoryConstantIsStable() {
        // Locks the subdirectory name so a future refactor can't silently
        // orphan all bridged image files on an in-place update.
        #expect(WidgetImageBridge.imageSubdirectory == "widget-images")
    }

    // MARK: - Helpers

    /// Remove the per-test container we created so test runs don't leak
    /// directories under `~/Library/Group Containers/` across the dev
    /// machine. Best-effort — swallows errors because the container may
    /// not exist (e.g. the test failed before any write).
    private static func cleanupContainer(identifier: String) {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) {
            try? FileManager.default.removeItem(at: containerURL)
        }
    }
}
