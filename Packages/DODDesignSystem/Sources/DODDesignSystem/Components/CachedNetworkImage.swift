import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// A hero/thumbnail image loader that replaces a raw `AsyncImage` in the recipe
/// cards (DUT-99).
///
/// **Why this exists.** Raw `AsyncImage` surfaced two device bugs on the feed:
/// (1) it reports a *cancelled* load — which happens constantly as cells
/// re-render or scroll off-screen — as `.failure`, so a card would flip to the
/// broken-`photo` placeholder even though the image is fine and reachable; and
/// (2) it shares no durable cache, so every re-render re-downloads, and on a
/// flaky connection a burst of simultaneous loads (during fast scroll +
/// pagination) trips the connection limit / request timeout and some never
/// recover. This view fixes both: it loads through a shared, **disk-backed
/// `URLCache`**, **retries** transient failures with backoff, and **never**
/// shows the failure placeholder merely because a load was cancelled.
///
/// **Visual parity.** The states map 1:1 onto the old `AsyncImage` switch so the
/// recorded snapshots are unchanged: loading — and a `nil` URL — render
/// ``LoadingSkeleton``; success renders the image `.fill`ed; only a genuine
/// failure after retries shows the `photo` placeholder.
public struct CachedNetworkImage: View {

    private let url: URL?
    private let skeletonCornerRadius: CGFloat
    /// Point size for the failure `photo` glyph; `nil` uses the default body
    /// size (the small list-row thumbnail). The gallery card passes 40.
    private let placeholderIconSize: CGFloat?

    public init(url: URL?, skeletonCornerRadius: CGFloat = 0, placeholderIconSize: CGFloat? = 40) {
        self.url = url
        self.skeletonCornerRadius = skeletonCornerRadius
        self.placeholderIconSize = placeholderIconSize
    }

    public var body: some View {
        #if canImport(UIKit)
        CachedImageLoaderView(
            url: url,
            skeletonCornerRadius: skeletonCornerRadius,
            placeholderIconSize: placeholderIconSize
        )
        #else
        // macOS build/test slice: a plain AsyncImage with matching phases
        // (the durable-cache + retry path is iOS-only; macOS is non-shipping).
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                LoadingSkeleton(cornerRadius: skeletonCornerRadius)
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                Self.failurePlaceholder(iconSize: placeholderIconSize)
            @unknown default:
                EmptyView()
            }
        }
        #endif
    }

    /// The broken-image placeholder — identical to the old `.failure` branch.
    /// `.font(nil)` keeps the environment default (the list-row thumbnail size).
    @ViewBuilder static func failurePlaceholder(iconSize: CGFloat?) -> some View {
        Image(systemName: "photo")
            .font(iconSize.map { Font.system(size: $0) })
            .foregroundStyle(DODColor.labelSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DODColor.surface)
    }
}

#if canImport(UIKit)

/// The iOS loader: caches, retries, and is cancellation-safe.
private struct CachedImageLoaderView: View {

    let url: URL?
    let skeletonCornerRadius: CGFloat
    let placeholderIconSize: CGFloat?

    @State private var phase: Phase = .loading

    private enum Phase: Equatable {
        case loading
        case image(UIImage)
        case failed
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                LoadingSkeleton(cornerRadius: skeletonCornerRadius)
            case .image(let uiImage):
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failed:
                CachedNetworkImage.failurePlaceholder(iconSize: placeholderIconSize)
            }
        }
        // Re-runs only when the URL actually changes (cell reuse), not on
        // every re-render — so a stable cell keeps its loaded image.
        .task(id: url) { await load() }
    }

    private func load() async {
        // A nil URL has nothing to load — keep the skeleton, matching the
        // old `AsyncImage(url: nil)` behavior (and the recorded snapshots).
        guard let url else { return }
        phase = .loading
        for attempt in 0..<3 {
            if Task.isCancelled { return }
            do {
                let (data, response) = try await Self.session.data(from: url)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 200
                guard (200..<400).contains(code), let image = UIImage(data: data) else {
                    throw URLError(.badServerResponse)
                }
                phase = .image(image)
                return
            } catch {
                // A cancelled load means the cell scrolled away or the URL
                // changed — NOT a real failure. Bail without flipping to the
                // placeholder (the core DUT-99 bug).
                if Task.isCancelled || (error as? URLError)?.code == .cancelled { return }
                if attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(300 * (attempt + 1)))
                }
            }
        }
        phase = .failed
    }

    /// Shared, disk-backed session so re-renders + revisits hit the cache
    /// instead of re-downloading (and racing the connection limit).
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()
}

#endif
