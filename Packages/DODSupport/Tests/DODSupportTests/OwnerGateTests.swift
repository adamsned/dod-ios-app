import Foundation
import Testing

@testable import DODSupport

// Daddy Mode (Phase 1, cosmetic) — `OwnerGate` gate coverage. As of 2026-07-09
// the gate is CONFIGURED with the owner's real `sub`, so these prove the two
// load-bearing properties in their live state: (1) the gate flips true for
// exactly the configured owner `sub`, and (2) it stays false for everyone else
// (nil / empty / whitespace / any other `sub`, including the old placeholder).
@Suite("OwnerGate (Daddy Mode Phase 1)")
struct OwnerGateTests {

    // MARK: - Configured owner: the gate is live and flips true for the owner

    @Test func ownerIsConfigured() {
        // Daddy Mode is activated: the shipped identifier is no longer the
        // unset placeholder, so the gate actually matches someone.
        #expect(OwnerGate.ownerUserIdentifier != OwnerGate.placeholderIdentifier)
        #expect(!OwnerGate.ownerUserIdentifier.isEmpty)
    }

    @Test func configuredOwnerSubIsOwner() {
        // The exact configured `sub` is the owner...
        #expect(OwnerGate.isOwner(OwnerGate.ownerUserIdentifier) == true)
        // ...and surrounding whitespace is trimmed before the compare.
        #expect(OwnerGate.isOwner("  \(OwnerGate.ownerUserIdentifier)\n") == true)
    }

    // MARK: - Everyone else → false

    @Test func nonOwnerSubsAreNotOwner() {
        // The old placeholder string, a real-looking-but-different `sub`, and an
        // arbitrary string are all NOT the owner.
        #expect(OwnerGate.isOwner(OwnerGate.placeholderIdentifier) == false)
        #expect(OwnerGate.isOwner("001234.some-real-looking-sub.5678") == false)
        #expect(OwnerGate.isOwner("anyone") == false)
    }

    @Test func nilSubIsNotOwner() {
        #expect(OwnerGate.isOwner(nil) == false)
    }

    @Test func emptyOrBlankSubIsNotOwner() {
        #expect(OwnerGate.isOwner("") == false)
        #expect(OwnerGate.isOwner("   ") == false)
        #expect(OwnerGate.isOwner("\n\t ") == false)
    }

    // MARK: - Session convenience

    @Test func isCurrentUserOwnerTrueForOwnerSession() {
        // A session whose `sub` is the configured owner resolves to owner.
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: OwnerGate.ownerUserIdentifier)
        )
        #expect(OwnerGate.isCurrentUserOwner(sessionStore: store) == true)
    }

    @Test func isCurrentUserOwnerFalseForOtherSession() {
        // Any other signed-in user is not the owner.
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "009999.not-the-owner.0001")
        )
        #expect(OwnerGate.isCurrentUserOwner(sessionStore: store) == false)
    }

    @Test func isCurrentUserOwnerFalseWithNoSession() {
        let store = InMemoryAppleAuthSessionStore()
        #expect(OwnerGate.isCurrentUserOwner(sessionStore: store) == false)
    }
}
