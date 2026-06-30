import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the DUT-417 / CL-292 profile-stats rank-hero caption
/// (`ProfileEditView.rankProgressCaption`). The underlying rank math lives in
/// DODSupport's `CookProgression` (separately tested); these pin the three
/// presentation states + the singular/plural "cook(s)" wording without a host.
///
/// Spec trace: US-44; CL-292.
@Suite("ProfileEditView stats caption (DUT-417)")
struct ProfileStatsTests {

    @Test func noCooksInvitesFirstCook() {
        let caption = ProfileEditView.rankProgressCaption(totalCooks: 0)
        #expect(caption == "Log your first cook to start climbing the ranks.")
    }

    @Test func climbingShowsRemainingToNextRank() {
        // 1 cook → Fire Starter; next is Coal Tender (threshold 3) → 2 to go.
        let caption = ProfileEditView.rankProgressCaption(totalCooks: 1)
        #expect(caption == "2 more cooks to 🪵 Coal Tender")
    }

    @Test func singularCookWhenOneAway() {
        // 4 cooks → Coal Tender; next is Lid Lifter (threshold 5) → 1 to go.
        let caption = ProfileEditView.rankProgressCaption(totalCooks: 4)
        #expect(caption == "1 more cook to 🍳 Lid Lifter")
    }

    @Test func topRankIsCelebrated() {
        // 50+ cooks → Dutch Oven Daddy, the top rank; no next rung.
        let caption = ProfileEditView.rankProgressCaption(totalCooks: 50)
        #expect(caption == "Top rank reached. You're a true Dutch Oven Daddy.")
    }
}
