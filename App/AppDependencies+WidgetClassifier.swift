import DODFeatureFeed
import DODNetworking
import Foundation

// DUT-460 — the widget's adaptive "Latest Recipe" / "Latest Article" eyebrow
// classifier, extracted from `AppDependencies.swift` for the file_length cap.
extension AppDependencies {

    /// Classifies the latest (top-of-feed) post's kind for the widget snapshot:
    /// fetch its page + JSON-LD parse. Returns `true` (article) only when the
    /// parse *definitively* found no Recipe block (CL-63). A missing URL or a
    /// fetch failure defaults to recipe (`false`).
    ///
    /// DUT-649 — the old `(try? …) == nil` treated ANY throw as "article",
    /// including transient parse errors, so a momentary blip could mislabel a
    /// recipe as an article. Now only the two structural "no Recipe here" errors
    /// (`.notFound` / `.noJSONLDBlocks`) mean article; every other throw defaults
    /// to recipe.
    func makeLatestKindClassifier() -> LiveFeedDependencies.LatestKindClassifier {
        let fetcher = pageFetcher
        return { item in
            guard let url = item.canonicalURL,
                let html = try? await fetcher.html(for: url)
            else { return false }
            do {
                _ = try JSONLDRecipeParser.parse(html: html, merging: item, canonicalURL: url)
                return false
            } catch JSONLDRecipeParser.Error.notFound, JSONLDRecipeParser.Error.noJSONLDBlocks {
                return true
            } catch {
                // Transient / unexpected failure — default to recipe (`false`)
                // rather than mislabeling as an article.
                return false
            }
        }
    }
}
