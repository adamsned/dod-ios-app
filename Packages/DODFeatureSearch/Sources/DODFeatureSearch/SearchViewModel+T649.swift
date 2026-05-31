import DODSupport
import Foundation

/// CL-127 (T-649): the "did you mean?" public surface + the threshold
/// constant. Split out of `SearchViewModel.swift` so that file stays
/// under SwiftLint's `file_length` cap after the suggestion-engine
/// wiring landed. Same split pattern the T-637 (`+T637`) / T-639
/// (`+T639`) / T-643 (`+T643`) extensions already follow on this
/// view-model. Helpers live in the extension; the storage they touch
/// (`didYouMean`, `query`) is `public internal(set)` on the main type
/// so same-module extensions can write it without forking the storage.
extension SearchViewModel {

    /// The result-count threshold below which the viewmodel computes
    /// a "did you mean?" suggestion. 3 is the minimum "result page
    /// feels populated" count on the 2-column gallery — one card is
    /// lonely, two reads as "is that all?", three fills the first
    /// scrolled row and the user trusts the search worked. Below that
    /// the banner intervenes.
    static var didYouMeanThreshold: Int { 3 }

    /// US-12 amendment / US-29 amendment / CL-127 (T-649): apply the
    /// engine's "did you mean?" suggestion. Overwrites `query` with
    /// the suggested string and nulls out `didYouMean` so the banner
    /// disappears immediately; the existing `query.didSet` debounce +
    /// `performSearch()` path re-runs against the new query and the
    /// view re-renders with the new result set. No-op when there is
    /// no current suggestion.
    public func applyDidYouMean() {
        guard let suggestion = didYouMean else { return }
        didYouMean = nil
        query = suggestion
    }
}
