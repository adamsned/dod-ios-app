import DODFeatureProfile
import DODSupport
import Foundation

// US-44 / CL-138 / DUT-36 Phase c — protocol default impls + live
// implementations for the profile-gate surface.
//
// Extracted from `RecipeDetailDependencies.swift` so that file stays
// under the SwiftLint 400-line `file_length` cap after the Phase c
// additions. The protocol declaration in the parent file references
// `loadUserProfile()`, `profileStoreForGate`, and (UIKit-gated)
// `profilePhotoStoreForGate` — the defaults here ensure existing fakes
// keep compiling without opting in, and the `LiveRecipeDetailDependencies`
// extension implements the production live reads.
//
// Spec trace: US-44 AC-44.10; CL-138; DUT-36 Phase c.

// MARK: - Protocol defaults

extension RecipeDetailDependencies {

    /// US-44 / CL-138 — default returns `nil` so any pre-Phase-c test
    /// fake (which doesn't care about profile gating) keeps compiling
    /// AND keeps reporting the "no profile" branch that the Phase a/b
    /// shipped contract assumes by default. Tests that exercise the
    /// gated/ungated split override this to return a canned
    /// ``UserProfile``. Production wires through
    /// ``LiveRecipeDetailDependencies``.
    public func loadUserProfile() async -> UserProfile? { nil }

    /// US-44 / CL-138 — default returns `nil` so existing fakes keep
    /// compiling. The gate's CTA falls back to a guarded inline
    /// message when no store is wired (the test-host condition);
    /// production always returns the singleton ``KeychainProfileStore``.
    public var profileStoreForGate: (any ProfileStoring)? { nil }

    #if canImport(UIKit)
    /// US-44 / CL-138 — default returns `nil` so existing fakes keep
    /// compiling; photo features in the gate-presented edit view
    /// degrade gracefully to the initial-letter avatar.
    public var profilePhotoStoreForGate: (any ProfilePhotoStoring)? { nil }
    #endif

    /// Daddy Mode (Phase 1, cosmetic) — default `0` so fakes that don't model
    /// the cook journal keep compiling (no rank attached). Live wiring reads the
    /// on-device cook logs.
    public func loadRankLadderCookCount() async -> Int { 0 }

    /// Daddy Mode (Phase 1, cosmetic) — default `nil` so fakes keep compiling and
    /// no owner badge shows. Live wiring reads the on-device SIWA session `sub`.
    public var currentUserIdentifier: String? { nil }
}

// MARK: - Live impls (LiveRecipeDetailDependencies)

extension LiveRecipeDetailDependencies {

    /// US-44 / CL-138 — read the on-device profile through the injected
    /// store. `nil` if no store was wired (test-only) or no profile has
    /// been saved (the guest-mode default). The
    /// ``RecipeDetailViewModel`` uses this for `hasProfile` gating of
    /// the Ratings & Reviews write surface.
    public func loadUserProfile() async -> UserProfile? {
        await profileStore?.load()
    }

    public var profileStoreForGate: (any ProfileStoring)? {
        profileStore
    }

    #if canImport(UIKit)
    public var profilePhotoStoreForGate: (any ProfilePhotoStoring)? {
        profilePhotoStore
    }
    #endif

    /// Daddy Mode (Phase 1, cosmetic) — the rank-ladder cook count from the same
    /// on-device journal (`RecipeStore.allCookLogs`) + pure `CookLogStats` the
    /// Settings profile Cook Rank uses, so a comment rank can't contradict it.
    public func loadRankLadderCookCount() async -> Int {
        let logs = (try? await store.allCookLogs()) ?? []
        return CookLogStats.rankLadderCookCount(logs)
    }

    /// Daddy Mode (Phase 1, cosmetic) — the current SIWA session `sub`, read
    /// through the same on-device store the rest of the app uses. `nil` when no
    /// one is signed in.
    public var currentUserIdentifier: String? {
        (try? KeychainAppleAuthSessionStore().load())?.userIdentifier
    }
}
