import CryptoKit
import Foundation

/// Image bridge between the host app's `RecipeStore.cacheImage(...)` site
/// and the home-screen widget extensions (featured + saved) that need to
/// render those bytes without a network fetch.
///
/// Widget extensions run in their own process. They can read files from the
/// shared App Group container but cannot reach the host's SwiftData store,
/// and constitution §9 implicit + spec AC-17.6 forbid widget-side network.
/// This bridge sits between those constraints:
///
///   - Host side: every time `RecipeStore.cacheImage(url:bytes:...)` writes
///     bytes into SwiftData, it also writes the same bytes to a file inside
///     the App Group container under a deterministic filename derived from
///     the URL.
///   - Snapshot wire format: ``WidgetSnapshot/Entry`` and
///     ``SavedRecipesWidgetSnapshot/Entry`` carry a `heroImageFilename`
///     populated from ``WidgetImageBridge/filename(for:)``.
///   - Widget side: the entry view resolves the filename to a `file://`
///     URL via ``WidgetImageBridge/fileURL(forFilename:)`` and hands it to
///     ``AsyncImage``. `file://` is a local read — not a network fetch.
///
/// Spec trace: spec.md US-21, AC-21.2 (host write hook), AC-21.3 (widget
/// resolution), AC-21.4 (eviction parity), CL-35 (file-export decision).
public enum WidgetImageBridge {

    /// Subdirectory under the App Group container where bridged image
    /// files live. Kept separate from any other shared files (the widget
    /// snapshot UserDefaults keys live in the same suite but in
    /// `UserDefaults`, not the file system) so a future caller can list
    /// the directory and reason about its contents without false hits.
    public static let imageSubdirectory = "widget-images"

    /// Filename extension used for bridged images. We do not preserve the
    /// source URL's extension because the WP CDN sometimes serves JPEG
    /// bytes from a `.jpg`, sometimes from a `.jpeg`, and (rarely) from a
    /// path that lacks an extension entirely. `AsyncImage` doesn't care
    /// about the extension — it sniffs the bytes — so a uniform `.img`
    /// suffix keeps the filename derivation purely a function of the
    /// URL string. (Using `.img` rather than `.jpg` also avoids a false
    /// promise that the bytes are JPEG when the source might be a PNG.)
    public static let imageFilenameExtension = "img"

    /// Deterministic filename for a given image URL. Same input always
    /// yields the same filename, across processes and across launches.
    ///
    /// Derivation: SHA256 hex of the absolute URL string + `.img`. The
    /// hash is content-addressed by URL (not bytes) so two different URLs
    /// pointing at the same image still produce two filenames — that's
    /// fine and matches how the host's `CachedImage` table is keyed.
    public static func filename(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(hex).\(imageFilenameExtension)"
    }

    /// Resolve a bridged filename to a `file://` URL pointing at the
    /// image inside the shared App Group container. Returns nil when the
    /// container can't be located (no entitlement, wrong simulator slice)
    /// so the widget renders its gradient placeholder rather than
    /// crashing.
    ///
    /// Does NOT check whether the file actually exists at the resolved
    /// path — `AsyncImage` swallows file-not-found gracefully and falls
    /// back to the empty phase, which the widget renders as the
    /// gradient placeholder. Avoiding the existence check here keeps
    /// this function pure (no I/O) and trivially testable.
    public static func fileURL(
        forFilename filename: String,
        appGroupIdentifier: String = WidgetSnapshotConfig.appGroupIdentifier
    ) -> URL? {
        guard let containerURL = imageDirectoryURL(appGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        return containerURL.appendingPathComponent(filename, isDirectory: false)
    }

    /// Directory inside the App Group container where bridged images
    /// live. Creates the directory on first call if it doesn't exist;
    /// returns nil when the container itself can't be located.
    ///
    /// Used by the host's write hook (creates files inside this
    /// directory) and indirectly by ``fileURL(forFilename:appGroupIdentifier:)``
    /// (which just appends the filename without checking existence).
    public static func imageDirectoryURL(
        appGroupIdentifier: String = WidgetSnapshotConfig.appGroupIdentifier
    ) -> URL? {
        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            )
        else {
            return nil
        }
        let directoryURL = containerURL.appendingPathComponent(
            imageSubdirectory,
            isDirectory: true
        )
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try? FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }
        // DUT-8: relax the directory's data-protection class to
        // `.completeUntilFirstUserAuthentication` so files an `.atomic`
        // write swaps into place inherit a widget-readable class even
        // before `writeImage`'s explicit per-file `setAttributes` runs.
        // This is the directory-level half of the locked-device read fix;
        // see `writeImage(bytes:for:appGroupIdentifier:)` for the full
        // rationale. Best-effort — failures leave the widget on its
        // gradient-placeholder fallback rather than breaking the write.
        applyWidgetReadableProtection(to: directoryURL)
        return directoryURL
    }

    /// Best-effort file write. Returns true on success; logs and returns
    /// false on any failure (including missing App Group container).
    /// Callers treat the return value as a hint, not a contract — even
    /// if the write fails the host's SwiftData cache is still authoritative
    /// and the widget gracefully falls back to its gradient placeholder
    /// when the file is absent.
    ///
    /// **Data-protection class (DUT-8 root cause).** The file is written
    /// with `.completeUntilFirstUserAuthentication` rather than the iOS
    /// default (`.complete`). This is the fix for the "widget still shows
    /// the fork-and-knife placeholder even though the `.img` files exist on
    /// disk" regression. A widget extension renders + refreshes its timeline
    /// in the background, including **while the device is locked** (Lock
    /// Screen, StandBy, background timeline builds, and the first render
    /// after a reboot before the user has unlocked). Files written with the
    /// default `.complete` protection are encrypted-at-rest and become
    /// **unreadable whenever the device is locked** — so
    /// `UIImage(contentsOfFile:)` inside `WidgetCard.Hero` returns nil and
    /// the hero collapses to the gradient placeholder. `.complete` is
    /// invisible to the L4 snapshot host (no data-protection lock there) and
    /// to a filesystem-level "are the files present?" check (they are), which
    /// is exactly why the two prior fixes verified green yet failed on a real
    /// home screen. `.completeUntilFirstUserAuthentication` keeps the bytes
    /// encrypted at rest but readable any time after the first unlock
    /// following boot — the protection class Apple documents for files an
    /// App-Group-sharing widget must read. We set it explicitly via both the
    /// write option AND a follow-up `setAttributes` so the class sticks even
    /// when `.atomic` swaps in a fresh inode whose protection would otherwise
    /// be re-derived from the directory default.
    @discardableResult
    public static func writeImage(
        bytes: Data,
        for url: URL,
        appGroupIdentifier: String = WidgetSnapshotConfig.appGroupIdentifier
    ) -> Bool {
        guard let directoryURL = imageDirectoryURL(appGroupIdentifier: appGroupIdentifier) else {
            return false
        }
        let fileURL = directoryURL.appendingPathComponent(
            filename(for: url),
            isDirectory: false
        )
        do {
            try bytes.write(to: fileURL, options: [.atomic, widgetReadableProtectionOption])
            // Belt-and-suspenders: `.atomic` writes to a temp file and
            // renames it into place, so the visible inode is brand-new and
            // (on some OS versions) inherits the directory's protection
            // class rather than the write option's. Re-assert the class on
            // the final path so a locked-device widget read can never be
            // blocked by `.complete`. Best-effort — a failure here still
            // leaves the bytes on disk (just possibly at the default class),
            // and the diagnostic below records that the write itself landed.
            applyWidgetReadableProtection(to: fileURL)
            // Diagnostic surface for REG-T-360 / CL-45. Mirror of the
            // debug log inside `RecipeStore.cacheImage(url:bytes:)` so
            // a future "the widget is still showing placeholder" report
            // can be triaged in one console pass — if the host log fires
            // but this one doesn't, the App Group entitlement / container
            // resolution broke; if both fire and the widget still shows
            // placeholder, the widget-side resolver or snapshot wire
            // format regressed.
            DODLog.persistence.debug(
                "WidgetImageBridge wrote \(bytes.count, privacy: .public)B to \(filename(for: url), privacy: .public)"
            )
            return true
        } catch {
            DODLog.app.error(
                "WidgetImageBridge write failed for \(filename(for: url), privacy: .public): \(String(describing: error))"
            )
            return false
        }
    }

    /// Best-effort file delete. Returns true if the file was deleted or
    /// didn't exist; logs and returns false on any unexpected failure
    /// (permissions, etc.). Callers treat this as fire-and-forget —
    /// the widget renders the gradient placeholder either way.
    @discardableResult
    public static func deleteImage(
        for url: URL,
        appGroupIdentifier: String = WidgetSnapshotConfig.appGroupIdentifier
    ) -> Bool {
        guard let directoryURL = imageDirectoryURL(appGroupIdentifier: appGroupIdentifier) else {
            return false
        }
        let fileURL = directoryURL.appendingPathComponent(
            filename(for: url),
            isDirectory: false
        )
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            // Treat "no such file" as the desired end state — the host's
            // `evictImagesIfNeeded()` calls delete unconditionally and a
            // missing file just means a previous cycle (or external
            // cleanup) already did the work. Anything else is a real
            // failure: log and return false so the caller knows.
            let nsError = error as NSError
            let isMissingFile =
                nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError
            if isMissingFile { return true }
            DODLog.app.error(
                "WidgetImageBridge delete failed for \(filename(for: url), privacy: .public): \(String(describing: error))"
            )
            return false
        }
    }

    // MARK: - Data protection (DUT-8)
    //
    // A widget extension reads these files in the background and while the
    // device is locked. The default iOS file-protection class (`.complete`)
    // makes the bytes unreadable whenever the device is locked, which is the
    // on-device-only cause of the "widget shows the placeholder even though
    // the files exist" regression. We pin `.completeUntilFirstUserAuthentication`
    // — encrypted at rest, readable after the first post-boot unlock — which
    // is the class Apple documents for App-Group files a widget must read.
    //
    // The `FileProtectionType` / `Data.WritingOptions` data-protection
    // symbols are iOS-only; the macOS `swift test` slice (DODSupport supports
    // macOS for its non-visual unit tests) has no per-file data protection,
    // so the helpers degrade to a no-op / plain `.atomic` write there.

    /// `Data.WritingOptions` that pins the widget-readable protection class
    /// on the initial write. No-op (`[]`) on macOS where the option and the
    /// underlying data-protection feature don't exist.
    static var widgetReadableProtectionOption: Data.WritingOptions {
        #if os(iOS)
        return .completeFileProtectionUntilFirstUserAuthentication
        #else
        return []
        #endif
    }

    /// Re-assert the widget-readable protection class on an already-existing
    /// file or directory at `url`. Best-effort: data protection is iOS-only,
    /// and a failure leaves the widget on its gradient-placeholder fallback
    /// rather than breaking the host's authoritative SwiftData cache.
    static func applyWidgetReadableProtection(to url: URL) {
        #if os(iOS)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
    }
}
