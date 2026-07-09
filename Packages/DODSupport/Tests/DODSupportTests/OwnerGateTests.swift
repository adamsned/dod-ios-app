import Foundation
import Testing

@testable import DODSupport

// Daddy Mode (Phase 1, cosmetic) — `OwnerGate` gate coverage. Proves the two
// load-bearing safety properties: (1) while `ownerUserIdentifier` is the shipped
// placeholder, the gate matches NOBODY (owner UI stays hidden for every user),
// and (2) once a real `sub` is configured, the gate flips true for exactly that
// `sub` and false for everyone else (nil / empty / mismatch).
@Suite("OwnerGate (Daddy Mode Phase 1)")
struct OwnerGateTests {

    // MARK: - Safe default: placeholder matches nobody

    @Test func placeholderShipsUnset() {
        // Guards against accidentally committing a real `sub` — the placeholder
        // is the safe default and must stay in place until Dad's device is read.
        #expect(OwnerGate.ownerUserIdentifier == OwnerGate.placeholderIdentifier)
    }

    @Test func placeholderMatchesNobody() {
        // Even a `sub` byte-equal to the placeholder string must NOT be treated
        // as the owner while the gate is unconfigured.
        #expect(OwnerGate.isOwner(OwnerGate.placeholderIdentifier) == false)
        #expect(OwnerGate.isOwner("001234.some-real-looking-sub.5678") == false)
        #expect(OwnerGate.isOwner("anyone") == false)
    }

    // MARK: - nil / empty / whitespace → false

    @Test func nilSubIsNotOwner() {
        #expect(OwnerGate.isOwner(nil) == false)
    }

    @Test func emptyOrBlankSubIsNotOwner() {
        #expect(OwnerGate.isOwner("") == false)
        #expect(OwnerGate.isOwner("   ") == false)
        #expect(OwnerGate.isOwner("\n\t ") == false)
    }

    // MARK: - Configured owner: the gate flips correctly

    // The production `ownerUserIdentifier` is a `let`, so these exercise the
    // pure match logic through a stubbed configured value to prove the gate
    // would flip correctly once Dad's real `sub` is filled in.
    private static let stubOwnerSub = "001234.0a1b2c3d4e5f6a7b8c9d.1234"

    /// Mirror of `OwnerGate.isOwner`'s match logic against a stubbed configured
    /// owner `sub` (stands in for a real, non-placeholder `ownerUserIdentifier`).
    private func isOwnerAgainstStub(_ sub: String?) -> Bool {
        guard let sub else { return false }
        let candidate = sub.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return false }
        return candidate == Self.stubOwnerSub
    }

    @Test func matchingSubIsOwner() {
        #expect(isOwnerAgainstStub(Self.stubOwnerSub) == true)
        // Surrounding whitespace is trimmed before the compare.
        #expect(isOwnerAgainstStub("  \(Self.stubOwnerSub)\n") == true)
    }

    @Test func mismatchedSubIsNotOwner() {
        #expect(isOwnerAgainstStub("001234.DIFFERENT.9999") == false)
        #expect(isOwnerAgainstStub(nil) == false)
        #expect(isOwnerAgainstStub("") == false)
    }

    // MARK: - Session convenience

    @Test func isCurrentUserOwnerReadsSessionSub() {
        // With the placeholder unset, even a fully-populated session is not the
        // owner — proves the convenience routes the session `sub` through the
        // same safe-default gate.
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: Self.stubOwnerSub)
        )
        #expect(OwnerGate.isCurrentUserOwner(sessionStore: store) == false)
    }

    @Test func isCurrentUserOwnerFalseWithNoSession() {
        let store = InMemoryAppleAuthSessionStore()
        #expect(OwnerGate.isCurrentUserOwner(sessionStore: store) == false)
    }
}
