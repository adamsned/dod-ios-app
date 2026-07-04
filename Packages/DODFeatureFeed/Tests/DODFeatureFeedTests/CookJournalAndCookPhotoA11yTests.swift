import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// Coverage for two low-severity Feed/Journal polish fixes:
/// - DUT-272: the Cooking Journal must not flash its empty state on open for a
///   user who has logged cooks (a load-order flicker).
/// - DUT-232: the finished-cook photo (celebrate stage) and the journal
///   thumbnail must expose meaningful VoiceOver labels.
///
/// Both fixes live in SwiftUI `body`/`@ViewBuilder` code. Following this
/// package's convention (see `FirstCookoutFeedBugBatchTests`), the load-order
/// decision and the label strings are exposed as pure helpers so they're
/// assertable without a live view hierarchy.
@MainActor
@Suite("Cooking Journal load-order + cook-photo a11y (DUT-272, DUT-232)")
struct CookJournalAndCookPhotoA11yTests {

    // MARK: - DUT-272 — no empty-state flash before the first load resolves

    /// Before the first async load resolves, `loaded` is false. Even though
    /// `cooks` is momentarily empty, the body must show the loading state, NOT
    /// the "No Cooks Logged Yet" empty state — that flash was the bug.
    @Test func journalShowsLoadingNotEmptyBeforeFirstLoadResolves() {
        #expect(CookJournalView.contentState(loaded: false, isEmpty: true) == .loading)
    }

    /// A user who genuinely has no cooks (a real load returned nothing) still
    /// gets the empty state — the fix gates on `loaded`, it doesn't hide it.
    @Test func journalShowsEmptyOnlyAfterAGenuineEmptyLoad() {
        #expect(CookJournalView.contentState(loaded: true, isEmpty: true) == .empty)
    }

    /// A user who has cooks lands directly on the list once loaded — and, before
    /// load, never sees the empty state even for a frame.
    @Test func journalWithCooksNeverFlashesEmpty() {
        // Pre-load frame (cooks not yet hydrated): loading, not empty.
        #expect(CookJournalView.contentState(loaded: false, isEmpty: true) == .loading)
        // Post-load frame (cooks present): the list.
        #expect(CookJournalView.contentState(loaded: true, isEmpty: false) == .list)
    }

    // MARK: - DUT-232 — cook photo / journal thumbnail carry VoiceOver labels

    /// The celebrate-stage photo label names the dish so VoiceOver reads more
    /// than a bare "image".
    @Test func finishedCookPhotoLabelNamesTheDish() {
        let view = FirstCookoutView(cookout: GuidedCookout.path[0])
        #expect(view.cookPhotoAccessibilityLabel == "Photo of your finished \(GuidedCookout.path[0].dishTitle)")
        #expect(!view.cookPhotoAccessibilityLabel.isEmpty)
    }

    /// The campfire capstone has no dish title, so its photo label uses the
    /// dish-agnostic phrasing rather than reading an empty dish name.
    @Test func campfireCookPhotoLabelIsDishAgnostic() {
        let view = FirstCookoutView(cookout: GuidedCookout.campfire)
        #expect(view.cookPhotoAccessibilityLabel == "Photo of your finished campfire cook")
    }

    /// The journal thumbnail exposes a non-empty, meaningful label (not "image").
    @Test func journalThumbnailHasAMeaningfulLabel() {
        #expect(CookJournalView.photoThumbnailAccessibilityLabel == "Photo of this cook")
        #expect(!CookJournalView.photoThumbnailAccessibilityLabel.isEmpty)
    }
}
