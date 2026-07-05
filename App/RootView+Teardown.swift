import DODFeatureRecipeDetail
import DODFeatureSearch
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
// Extracted from `RootView.swift` so that file stays under the SwiftLint
// `file_length` cap (mirrors the `ProfileEditView+Teardown.swift` split).
extension RootView {

    /// Extra teardown handed to `ProfileEditView`. Runs on BOTH Sign Out and
    /// Delete (the `Bool` is `revoke` — unused here: this local state is wiped
    /// regardless) so User A's raw recent queries + block list never leak to
    /// User B on a shared device.
    var accountTeardownExtras: @MainActor (Bool) async -> Void {
        let moderation = commentModeration
        return { _ in
            RecentSearches().clear()
            moderation.clear()
        }
    }
}
