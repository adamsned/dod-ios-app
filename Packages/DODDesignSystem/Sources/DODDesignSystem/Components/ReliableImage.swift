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

/// DUT-520: how a thrown `URLError` should be handled by the hero loader.
/// Platform-independent (pure `Foundation`) so the retry policy is unit-testable
/// on the macOS test slice, where `ReliableImageLoader` itself is a UIKit-less
/// stub.
enum ReliableImageRetryDecision: Equatable {
    /// A recycled cell (DUT-201): `URLSession` surfaces Task cancellation as
    /// `URLError(.cancelled)`. Must not flip the cell to failure.
    case cancelled
    /// A momentary connectivity blip a second attempt can plausibly recover.
    case retry
    /// Permanent (bad URL, unsupported response, etc.) — fail fast instead of
    /// burning a second full fetch.
    case terminal
}

enum ReliableImageRetry {
    /// Classify a thrown `URLError` for the hero loader. Only genuinely transient
    /// connectivity errors retry; everything else is terminal so a permanent
    /// failure resolves the cell immediately.
    static func decision(for error: URLError) -> ReliableImageRetryDecision {
        switch error.code {
        case .cancelled:
            return .cancelled
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
            .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet:
            return .retry
        default:
            return .terminal
        }
    }
}

/// DUT-516: an in-flight coalescing map keyed by URL. Two concurrent callers for
/// the same URL share ONE underlying `Task` (one network fetch + one off-main
/// decode) instead of each issuing a separate request; the entry is removed with
/// identity-checked cleanup when the task completes (mirrors `ImageLoader` in
/// DODNetworking, re-implemented locally so DODDesignSystem takes no dependency
/// on DODNetworking).
///
/// Generic over the produced value + the run closure so the coalescing logic is
/// unit-testable without UIKit: the test drives it with a trivial value type and
/// asserts N concurrent same-key calls trigger exactly ONE run.
///
/// The stored `Task` is unstructured, so an individual caller's cancellation
/// (its `.task(id:)` being torn down when a cell recycles) does NOT cancel the
/// shared task for the other callers still awaiting it (DUT-201-safe).
actor InFlightCoalescer<Key: Hashable & Sendable, Value: Sendable> {

    private var inFlight: [Key: Task<Value, Never>] = [:]

    /// Diagnostic / test introspection: how many distinct keys are mid-flight.
    var inFlightCount: Int { inFlight.count }

    /// Return the value for `key`, sharing an in-flight task when one exists.
    /// The first caller for a key starts `run`; concurrent callers await the
    /// same task. `run` is invoked at most once per in-flight generation.
    func value(for key: Key, run: @Sendable @escaping () async -> Value) async -> Value {
        if let existing = inFlight[key] {
            return await existing.value
        }
        let task = Task<Value, Never> { await run() }
        inFlight[key] = task
        let value = await task.value
        // Identity-checked cleanup: only clear the slot if it still holds THIS
        // task, so a newer task queued for the same key after we finished isn't
        // clobbered (same guard as DODNetworking's `ImageLoader`).
        if inFlight[key] == task { inFlight[key] = nil }
        return value
    }
}

#if canImport(UIKit)

/// Shared in-memory cache of decoded recipe images, keyed by absolute URL.
/// `NSCache` is thread-safe and evicts under memory pressure.
///
/// DUT-251: bounded by decoded-pixel memory (`totalCostLimit`, ~64 MB) rather
/// than object count, and each entry's cost is its decoded byte estimate
/// (`width * height * 4`). A count limit let up to 250 full-res decodes sit in
/// RAM regardless of total size; the cost limit caps the actual bitmap memory
/// and lets `NSCache` evict the largest / least-recently-used entries first.
final class RecipeImageCache: @unchecked Sendable {
    static let shared = RecipeImageCache()
    private let cache = NSCache<NSString, UIImage>()

    /// ~64 MB of decoded bitmaps. At the 1200px downsample ceiling a hero is
    /// well under ~6 MB, so this holds a healthy working set for a feed scroll
    /// while staying bounded under memory pressure.
    private static let totalCostLimit = 64 * 1024 * 1024

    private init() { cache.totalCostLimit = Self.totalCostLimit }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func insert(_ image: UIImage, for url: URL) {
        let size = image.size
        let scale = image.scale
        let cost = ImageDownsampler.decodedByteCost(
            width: Int(size.width * scale),
            height: Int(size.height * scale)
        )
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
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

    /// DUT-520: dedicated hardened session instead of `URLSession.shared`.
    /// `URLSession.shared` leaves `timeoutIntervalForResource` at its 7-day
    /// default, so a slow/trickling hero body parks the `await` effectively
    /// forever (a feed cell never resolves). Cap the whole transfer at 30s and
    /// disable connectivity-waiting so an offline device fails fast instead of
    /// stalling. Mirrors the DUT-519 hardening in `URLSessionHTTPClient`.
    private nonisolated static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    /// DUT-516: the shared result of one coalesced fetch+decode. `Sendable`
    /// (`UIImage` is `Sendable`) so it crosses the coalescer actor cleanly.
    /// `.cancelled` is preserved distinctly so a shared attempt that surfaced
    /// `URLError(.cancelled)` leaves every caller's phase untouched (DUT-201),
    /// exactly as the pre-coalescing loop did.
    enum CoalescedOutcome: Sendable {
        case image(UIImage)
        case cancelled
        case failed
    }

    /// DUT-516: process-wide in-flight coalescing keyed by URL. Two visible cells
    /// with the same hero URL (or a cell reappearing mid-load) share ONE fetch +
    /// decode instead of each issuing a separate request. Cancellation stays a
    /// per-caller concern, so a recycled cell scrolling away never fails the load
    /// for the other cells still sharing it (DUT-201-safe).
    private nonisolated static let coalescer = InFlightCoalescer<URL, CoalescedOutcome>()

    func load(_ url: URL?) async {
        guard let url else {
            phase = .failure
            return
        }
        // Cached decode -> instant, no flicker on scroll/reuse. Short-circuits
        // BEFORE coalescing so a cache hit never touches the shared map (DUT-516).
        if let cached = RecipeImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }
        // New/uncached URL: show the placeholder while (re)loading so a reused
        // cell never flashes the previous recipe's photo.
        phase = .empty
        // Recycled cell (DUT-201): the .task(id:) was cancelled — don't touch phase.
        if Task.isCancelled { return }
        // DUT-516: run the fetch+retry+decode through the coalescer so concurrent
        // same-URL callers share one network task. The `run` closure is
        // unstructured inside the coalescer, so THIS caller's cancellation never
        // cancels the shared work for the others.
        let outcome = await Self.coalescer.value(for: url) { await Self.fetchAndDecode(url) }
        // Post-await cancellation re-check (DUT-201): a resumed-stale task must
        // not overwrite the new URL's phase after the cell recycled.
        if Task.isCancelled { return }
        switch outcome {
        case .image(let image):
            RecipeImageCache.shared.insert(image, for: url)
            phase = .success(Image(uiImage: image))
        case .cancelled:
            // The shared attempt surfaced URLError(.cancelled) — leave the phase
            // alone; the next appearance reloads (DUT-201).
            return
        case .failed:
            // Terminal failure (or exhausted retries): fall back to the offline
            // disk provider, then fail (DUT-377). Per-caller, not shared.
            await loadFromDiskOrFail(url)
        }
    }

    /// DUT-516: the shared fetch+retry+decode body, run once per in-flight URL by
    /// the coalescer. Preserves the DUT-520 retry policy: only a genuinely
    /// transient blip retries once; a permanent error / decode failure is
    /// terminal, and a `URLError(.cancelled)` is reported distinctly so a live
    /// caller's phase is never flipped to failure (DUT-201).
    private nonisolated static func fetchAndDecode(_ url: URL) async -> CoalescedOutcome {
        for _ in 0..<2 {
            switch await fetchOnce(url) {
            case .image(let image):
                return .image(image)
            case .cancelled:
                return .cancelled
            case .failed:
                return .failed
            case .retry:
                continue
            }
        }
        return .failed
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
        if let data = await provider(url), let image = await Self.decode(data) {
            if Task.isCancelled { return }
            RecipeImageCache.shared.insert(image, for: url)
            phase = .success(Image(uiImage: image))
            return
        }
        if !Task.isCancelled { phase = .failure }
    }

    /// DUT-251: decode image bytes to a display-sized `UIImage`, downsampling
    /// via ImageIO to the ``ImageDownsampler/maxPixelSize`` ceiling so a
    /// full-res WP hero no longer holds a multi-MB bitmap for a card-size
    /// render. Falls back to a plain `UIImage(data:)` decode only if ImageIO
    /// can't produce a thumbnail (e.g. an exotic format), preserving the prior
    /// behavior for that edge case. The DISK cache bytes are untouched — this
    /// only bounds the in-memory decode used for display.
    ///
    /// DUT-465: `nonisolated async`. This class is `@MainActor`, so a plain
    /// static would inherit main-actor isolation and — because
    /// `ImageDownsampler.downsample` uses `kCGImageSourceShouldCacheImmediately`
    /// to force full decompression at the call site — decompress the hero ON
    /// the main thread, hitching scroll. `nonisolated async` runs the decode on
    /// the global executor; only the `phase` publish hops back to the main
    /// actor. (`await` from `loadFromDiskOrFail`/`fetchOnce` keeps it off-main.)
    private nonisolated static func decode(_ data: Data) async -> UIImage? {
        if let cgImage = ImageDownsampler.downsample(data: data) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(data: data)
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
    ///
    /// DUT-520: uses the hardened ``session`` with an explicit 30s per-request
    /// timeout, and classifies outcomes so a permanent error resolves the cell
    /// immediately instead of burning a second full fetch:
    /// - a non-2xx response (404/403/5xx) is TERMINAL (`.failed`) — a retry of a
    ///   permanent error just doubles the latency before the cell fails,
    /// - a decode failure is TERMINAL (`.failed`) — a truncated / HTML-error body
    ///   won't become an image on a re-fetch,
    /// - only a genuinely transient `URLError` (timeout / network-lost /
    ///   cannot-connect) yields `.retry`.
    private nonisolated static func fetchOnce(_ url: URL) async -> FetchOutcome {
        let request = URLRequest(url: url, timeoutInterval: 30)
        do {
            let (data, response) = try await session.data(for: request)
            if Task.isCancelled { return .cancelled }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return .failed
            }
            return await Self.decode(data).map(FetchOutcome.image) ?? .failed
        } catch is CancellationError {
            return .cancelled
        } catch let error as URLError {
            // DUT-520: classify via the platform-independent policy so a
            // permanent error fails fast and only a transient blip retries.
            switch ReliableImageRetry.decision(for: error) {
            case .cancelled: return .cancelled
            case .retry: return .retry
            case .terminal: return .failed
            }
        } catch {
            return .failed
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
