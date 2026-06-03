import Foundation
import SwiftUI
import Testing

@testable import DODFeatureRecipeDetail

/// L1 — pin the contract on ``RatingsProfileGate``:
/// 1. The view builds without crashing on a `nil`-callback caller.
/// 2. The callback closure is invoked when the call site fires it.
///
/// The view body is exercised more thoroughly via the L4 snapshot pair
/// (``RecipeDetailRatingsViewSnapshotTests/test_section_gatedState_renders``)
/// — we don't snapshot the gate in isolation because it always renders
/// inside the section's ZStack overlay context.
///
/// Spec trace: US-44 AC-44.10; CL-138; DUT-36 Phase c.
@MainActor
@Suite("RatingsProfileGate (T-741)") struct RatingsProfileGateTests {

    @Test func gateBuildsWithCallback() {
        let gate = RatingsProfileGate(onSetUpProfile: {})
        // Touching `.body` proves the view tree builds without crashing
        // even though we don't host it (the L4 snapshot pair locks the
        // actual rendering — this just pins the constructor contract).
        _ = gate.body
    }

    @Test func onSetUpProfileClosureFiresWhenInvoked() {
        // The view stores the closure; the L4 snapshot pair covers the
        // tap path through SwiftUI's button. This test pins the
        // straight closure-invocation contract.
        var callbackFired = false
        let gate = RatingsProfileGate(onSetUpProfile: { callbackFired = true })
        gate.onSetUpProfile()
        #expect(callbackFired == true)
    }
}
