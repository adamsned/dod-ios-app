import Foundation
import Testing

@testable import DODSupport

/// DUT-157 — pure eligibility rules for the review prompt.
@Suite("ReviewPromptPolicy (DUT-157)")
struct ReviewPromptPolicyTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    /// A snapshot that passes every rule: 5 sessions, 10 views, 0 cooks.
    private func passing(
        _ mutate: (inout ReviewPromptPolicy.Snapshot) -> Void = { _ in }
    ) -> ReviewPromptPolicy.Snapshot {
        var snapshot = ReviewPromptPolicy.Snapshot(
            sessionCount: 5,
            recipeViewCount: 10,
            completedCookCount: 0
        )
        mutate(&snapshot)
        return snapshot
    }

    @Test func baselineIsEligible() {
        #expect(ReviewPromptPolicy.isEligible(passing(), now: now))
    }

    @Test func firstLaunchIsNotEligible() {
        #expect(!ReviewPromptPolicy.isEligible(passing { $0.sessionCount = 1 }, now: now))
    }

    @Test func activeCookIsNotEligible() {
        #expect(!ReviewPromptPolicy.isEligible(passing { $0.isCooking = true }, now: now))
    }

    @Test func recentErrorIsNotEligible() {
        #expect(!ReviewPromptPolicy.isEligible(passing { $0.hadRecentError = true }, now: now))
    }

    @Test func declinedIsNotEligible() {
        #expect(!ReviewPromptPolicy.isEligible(passing { $0.declined = true }, now: now))
    }

    @Test func promptedTenDaysAgoIsNotEligible() {
        let snap = passing { $0.lastPromptDate = now.addingTimeInterval(-10 * day) }
        #expect(!ReviewPromptPolicy.isEligible(snap, now: now))
    }

    @Test func promptedTwoHundredDaysAgoIsEligible() {
        let snap = passing { $0.lastPromptDate = now.addingTimeInterval(-200 * day) }
        #expect(ReviewPromptPolicy.isEligible(snap, now: now))
    }

    @Test func noViewsAndNoCooksIsNotEligible() {
        let snap = passing {
            $0.recipeViewCount = 0
            $0.completedCookCount = 0
        }
        #expect(!ReviewPromptPolicy.isEligible(snap, now: now))
    }

    @Test func noViewsButOneCookIsEligible() {
        let snap = passing {
            $0.recipeViewCount = 0
            $0.completedCookCount = 1
        }
        #expect(ReviewPromptPolicy.isEligible(snap, now: now))
    }
}
