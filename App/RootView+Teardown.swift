import DODFeatureRecipeDetail
import DODFeatureSearch
import DODSupport
import SwiftUI

// DUT-565 — account-teardown completeness. `ProfileEditView`'s Sign Out / Delete
// clears the profile, Apple session, guest identity, and Google tokens, but the
// Profile package can't reach the recent-search history (DODFeatureSearch) or the
// comment-moderation state (DODFeatureRecipeDetail) — adding those dependency
// edges would be wrong. So `RootView`, the composition root that already owns the
// app-global `commentModeration` and can build a `RecentSearches`, supplies the
// clears as an injected closure threaded into the editor (Settings sheet + iPad
// `SidebarProfileRow`).
//
// SDET bug hunt — the cook journal (DODPersistence `CachedCookLogEntry`,
// reached via `dependencies.store`) is the SAME class of leak: local-only,
// device-private data (reflection notes, personal ratings, photos) that this
// teardown never reached, so it survived Sign Out / Delete Profile and leaked
// forward — as the NEXT signed-in user's own "Cook Rank" / journal — to
// whoever signs into the same shared device next. `deleteAllCookLogs()` is
// best-effort like the other clears here: a failure (e.g. a transient
// SwiftData error) must not block Sign Out / Delete Profile from completing.
//
// Extracted from `RootView.swift` so that file stays under the SwiftLint
// `file_length` cap (mirrors the `ProfileEditView+Teardown.swift` split).
extension RootView {

    /// Extra teardown handed to `ProfileEditView`. Runs on BOTH Sign Out and
    /// Delete (the `Bool` is `revoke` — unused here: this local state is wiped
    /// regardless) so User A's raw recent queries, block list, and private cook
    /// journal never leak to User B on a shared device.
    var accountTeardownExtras: @MainActor (Bool) async -> Void {
        let moderation = commentModeration
        let store = dependencies.store
        return { _ in
            RecentSearches().clear()
            moderation.clear()
            // Best-effort like the clears above: a failure here must not block
            // Sign Out / Delete Profile, but it's logged (not swallowed) so a
            // stranded, un-cleared cook journal is observable in the field
            // rather than lost — mirroring the DUT-678 revoke-failure logging.
            do {
                try await store.deleteAllCookLogs()
            } catch {
                DODLog.persistence.error(
                    "Cook-journal teardown clear FAILED during account Sign Out / Delete; other teardown steps still completed. error=\(String(describing: error), privacy: .public)"
                )
            }
        }
    }
}
