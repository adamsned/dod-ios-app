import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The load state of a ``ReliableImage`` — mirrors `AsyncImage.Phase` (minus the
/// associated error) so call sites swap in with no structural change.
public enum ReliableImagePhase {
    case empty
    case success(Image)
    case failure
}

/// A reliable, cached network image for recipe heroes (DUT-195).
///
/// SwiftUI's `AsyncImage` makes the feed look broken: it drops to its
/// failure/empty phase on a transient error (no retry), **cancels in-flight
/// loads as cells recycle during scroll** (the cell reappears stuck on the
/// placeholder), and doesn't cache decoded images across cell reuse. This view
/// fixes all three:
///
/// - an in-memory decoded-image cache (``RecipeImageCache``) so a re-appearing
///   cell shows instantly with no reload/flicker,
/// - `URLSession` (backed by the shared `URLCache` for disk caching) with a
///   single retry on transient failure,
/// - on cancellation (scrolled away mid-load) it leaves the phase alone instead
///   of flipping to the broken-image placeholder; the next appearance reloads.
///
/// API mirrors `AsyncImage(url:content:)`, so swapping is a one-line change.
public struct ReliableImage<Content: View>: View {

    private let url: URL?
    private let content: (ReliableImagePhase) -> Content
    @State private var loader = ReliableImageLoader()

    public init(url: URL?, @ViewBuilder content: @escaping (ReliableImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    public var body: some View {
        content(loader.phase)
            // Re-runs when the cell is reused for a different recipe; cancels the
            // prior load (handled gracefully in `load`).
            .task(id: url) { await loader.load(url) }
    }
}

/// DUT-377: composition-root hook giving `ReliableImage` an offline disk
/// fallback. The app wires this once at launch to `RecipeStore.image(url:)` so a
/// saved / downloaded recipe's pinned hero renders offline — the app's image
/// rendering otherwise never read the persisted image cache. No-op where UIKit is
/// unavailable (the macOS test slice renders network-only).
public enum ReliableImageConfig {
    public static func setOfflineDataProvider(
        _ provider: @escaping @Sendable (URL) async -> Data?
    ) {
        #if canImport(UIKit)
        ReliableImageLoader.offlineDataProvider = provider
        #endif
    }
}

#if canImport(UIKit)

/// Shared in-memory cache of decoded recipe images, keyed by absolute URL.
/// `NSCache` is thread-safe and evicts under memory pressure.
final class RecipeImageCache: @unchecked Sendable {
    static let shared = RecipeImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() { cache.countLimit = 250 }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }
}

@MainActor @Observable
final class ReliableImageLoader {

    private(set) var phase: ReliableImagePhase = .empty

    /// DUT-377: optional disk fallback, consulted ONLY when the network load
    /// fails. The app's image rendering otherwise never read the persisted
    /// `CachedImage` store (saved / downloaded recipes' pinned hero bytes), so a
    /// saved recipe opened offline showed only a placeholder. The composition root
    /// wires this to `RecipeStore.image(url:)` once at launch; `nil` in previews /
    /// tests (network-only, behavior unchanged).
    nonisolated(unsafe) static var offlineDataProvider: (@Sendable (URL) async -> Data?)?

    func load(_ url: URL?) async {
        guard let url else {
            phase = .failure
            return
        }
        // Cached decode -> instant, no flicker on scroll/reuse.
        if let cached = RecipeImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }
        // New/uncached URL: show the placeholder while (re)loading so a reused
        // cell never flashes the previous recipe's photo.
        phase = .empty
        for _ in 0..<2 {
            // Recycled cell (DUT-201): the .task(id:) was cancelled — don't touch phase.
            if Task.isCancelled { return }
            switch await Self.fetchOnce(url) {
            case .image(let image):
                RecipeImageCache.shared.insert(image, for: url)
                phase = .success(Image(uiImage: image))
                return
            case .cancelled:
                return
            case .failed:
                await loadFromDiskOrFail(url)
                return
            case .retry:
                continue
            }
        }
        if !Task.isCancelled { await loadFromDiskOrFail(url) }
    }

    /// DUT-377: the network gave up — fall back to the persisted image store
    /// (`offlineDataProvider`, wired to `RecipeStore.image(url:)`) so a saved /
    /// downloaded recipe's pinned hero still renders offline. Only consulted on
    /// network failure, so the online path is unchanged (no per-image disk hit
    /// when the network succeeds).
    private func loadFromDiskOrFail(_ url: URL) async {
        if Task.isCancelled { return }
        guard let provider = Self.offlineDataProvider else {
            phase = .failure
            return
        }
        if let data = await provider(url), let image = UIImage(data: data) {
            if Task.isCancelled { return }
            RecipeImageCache.shared.insert(image, for: url)
            phase = .success(Image(uiImage: image))
            return
        }
        if !Task.isCancelled { phase = .failure }
    }

    private enum FetchOutcome {
        case image(UIImage)
        case cancelled
        case retry
        case failed
    }

    /// One fetch + decode attempt. Reports cancellation distinctly (DUT-201:
    /// URLSession surfaces Task cancellation as `URLError(.cancelled)`, NOT
    /// `CancellationError`) so the caller never flips a recycled cell to failure,
    /// and re-checks `Task.isCancelled` after the await so a resumed-stale task
    /// can't overwrite the new URL's phase.
    private static func fetchOnce(_ url: URL) async -> FetchOutcome {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if Task.isCancelled { return .cancelled }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return .retry
            }
            return UIImage(data: data).map(FetchOutcome.image) ?? .failed
        } catch is CancellationError {
            return .cancelled
        } catch let error as URLError where error.code == .cancelled {
            return .cancelled
        } catch {
            return .retry
        }
    }
}

#else

/// macOS `swift test` slice: DODDesignSystem builds for non-visual tests, which
/// never load network images. A no-op loader keeps the type cross-platform.
@MainActor @Observable
final class ReliableImageLoader {
    private(set) var phase: ReliableImagePhase = .empty
    func load(_ url: URL?) async { phase = url == nil ? .failure : .empty }
}

#endif
