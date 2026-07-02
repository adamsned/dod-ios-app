import DODFeatureFeed
import DODNetworking
import Foundation

// DUT-460 — the widget's adaptive "Latest Recipe" / "Latest Article" eyebrow
// classifier, extracted from `AppDependencies.swift` for the file_length cap.
extension AppDependencies {

    /// Classifies the latest (top-of-feed) post's kind for the widget snapshot:
    /// fetch its page + JSON-LD parse. A parse throw means there's no parseable
    /// Recipe block → article (CL-63). Defensive `try?` everywhere, so any fetch
    /// or parse failure (or a missing URL) defaults to recipe (`false`).
    func makeLatestKindClassifier() -> LiveFeedDependencies.LatestKindClassifier {
        let fetcher = pageFetcher
        return { item in
            guard let url = item.canonicalURL,
                let html = try? await fetcher.html(for: url)
            else { return false }
            return (try? JSONLDRecipeParser.parse(html: html, merging: item, canonicalURL: url)) == nil
        }
    }
}
