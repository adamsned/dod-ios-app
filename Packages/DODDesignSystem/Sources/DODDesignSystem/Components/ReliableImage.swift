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
        for attempt in 0..<2 {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    if attempt == 0 { continue }
                    break
                }
                if let image = UIImage(data: data) {
                    RecipeImageCache.shared.insert(image, for: url)
                    phase = .success(Image(uiImage: image))
                    return
                }
                break
            } catch is CancellationError {
                // Scrolled away mid-load. Leave the phase as-is; the next
                // appearance reloads (from cache if a sibling cell finished it).
                return
            } catch {
                if attempt == 0 { continue }
            }
        }
        phase = .failure
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
