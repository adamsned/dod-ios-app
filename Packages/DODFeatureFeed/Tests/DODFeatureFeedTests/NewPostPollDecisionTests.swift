import Testing

@testable import DODFeatureFeed

/// L1 unit coverage for the DUT-15 / T-787 background-poll decision. Pins the
/// truth table that protects the NFR-3 invariants: no alert on first run, no
/// duplicate alert, and no alert when the newest id moves backwards.
@Suite("NewPostPollDecision (DUT-15 / T-787)")
struct NewPostPollDecisionTests {

    /// First run: nothing was seen before, so skip and let the caller record a
    /// baseline. Prevents a spurious "new post" alert for an old post the
    /// instant notifications are enabled (NFR-3 "no surprise alert on install").
    @Test func firstRunSkipsToRecordBaseline() {
        #expect(NewPostPollDecision.decide(latestPostID: 4321, lastSeenPostID: nil) == .skip)
    }

    /// A strictly-newer id is the only case that notifies.
    @Test func strictlyNewerNotifies() {
        #expect(NewPostPollDecision.decide(latestPostID: 4322, lastSeenPostID: 4321) == .notify(postID: 4322))
    }

    /// Same id (re-poll before the baseline advanced, or an edited top post that
    /// kept its id) must not re-alert.
    @Test func sameIDSkips() {
        #expect(NewPostPollDecision.decide(latestPostID: 4321, lastSeenPostID: 4321) == .skip)
    }

    /// Newest id moved backwards (the top post was deleted) — skip; never lower
    /// the baseline into a state that would re-alert later.
    @Test func backwardIDSkips() {
        #expect(NewPostPollDecision.decide(latestPostID: 4300, lastSeenPostID: 4321) == .skip)
    }

    /// A large forward jump (several posts published between polls) still
    /// notifies once, for the newest id.
    @Test func forwardJumpNotifiesNewest() {
        #expect(NewPostPollDecision.decide(latestPostID: 4400, lastSeenPostID: 4321) == .notify(postID: 4400))
    }
}
