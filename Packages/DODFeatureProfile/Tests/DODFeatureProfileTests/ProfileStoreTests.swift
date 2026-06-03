import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the in-memory ``InMemoryProfileStore`` round-trip,
/// clear-removes-the-entry, and the load-after-clear-returns-nil
/// contract.
///
/// The Keychain-backed ``KeychainProfileStore`` cannot be exercised by
/// plain `swift test` on macOS — `SecItem*` is unreliable outside a
/// signed bundle, exactly like ``GuestIdentityStoreTests`` already
/// documents. The in-memory store mirrors the Keychain store's
/// validation surface (both run the same pre-flight
/// ``UserProfile/validateDisplayName(_:)`` / ``validateEmail(_:)``)
/// so the rules are pinned here, with the SecItem-side plumbing left
/// to the iOS-simulator xcodebuild path + L3 smoke verification.
///
/// Spec trace: US-44 AC-44.2, AC-44.4, AC-44.6; CL-136.
@Suite("ProfileStore (T-739)")
struct ProfileStoreTests {

    // MARK: - Round-trip

    @Test func saveThenLoadReturnsSameProfile() async throws {
        let store = InMemoryProfileStore()
        let id = UUID()
        let profile = UserProfile(
            id: id,
            displayName: "Spencer Adams",
            email: "spencer@example.com"
        )

        try await store.save(profile)
        let loaded = await store.load()

        #expect(loaded == profile)
        #expect(loaded?.id == id)
    }

    @Test func loadOnFreshStoreReturnsNil() async {
        let store = InMemoryProfileStore()
        let loaded = await store.load()
        #expect(loaded == nil)
    }

    @Test func saveOverwritesPreviousProfile() async throws {
        let store = InMemoryProfileStore()
        let first = UserProfile(
            id: UUID(),
            displayName: "Sam",
            email: "sam@example.com"
        )
        let second = UserProfile(
            id: first.id,
            displayName: "Samantha",
            email: "samantha@example.com"
        )

        try await store.save(first)
        try await store.save(second)
        let loaded = await store.load()

        #expect(loaded?.displayName == "Samantha")
        #expect(loaded?.email == "samantha@example.com")
        #expect(loaded?.id == first.id)
    }

    // MARK: - Clear semantics (Sign Out + Delete Profile)

    @Test func clearRemovesTheEntry() async throws {
        let store = InMemoryProfileStore()
        let profile = UserProfile(
            id: UUID(),
            displayName: "Ned",
            email: "ned@example.com"
        )

        try await store.save(profile)
        #expect(await store.hasProfile == true)

        try await store.clear()

        #expect(await store.hasProfile == false)
        #expect(await store.load() == nil)
    }

    @Test func clearIsIdempotent() async throws {
        let store = InMemoryProfileStore()
        // Two clears in a row should not throw, even with no profile
        // present — matches the Keychain `errSecItemNotFound`
        // graceful-degradation contract.
        try await store.clear()
        try await store.clear()
        #expect(await store.load() == nil)
    }

    // MARK: - Pre-flight validation (network-layer backstop pattern)

    @Test func saveOfBlankDisplayNameThrows() async throws {
        let store = InMemoryProfileStore()
        let bad = UserProfile(id: UUID(), displayName: "  ", email: "foo@example.com")

        await #expect(throws: ProfileStoreError.self) {
            try await store.save(bad)
        }
    }

    @Test func saveOfInvalidEmailThrows() async throws {
        let store = InMemoryProfileStore()
        let bad = UserProfile(id: UUID(), displayName: "Spencer", email: "not-an-email")

        await #expect(throws: ProfileStoreError.self) {
            try await store.save(bad)
        }
    }

    // MARK: - US-15 guest UUID bridge

    #if canImport(UIKit)
    @Test func clearAlsoClearsThePhotoFile() async throws {
        // Phase b — AC-44.9. ProfileStore.clear() must also call
        // `photoStore.clear(filename:)` on the current profile's
        // photoFilename so Sign Out + Delete Profile leave both
        // Keychain + Documents in the same clean state. Pinned via the
        // in-memory photo store fake whose `clearedFilenames` records
        // every call.
        let photoStore = InMemoryProfilePhotoStore()
        let filename = "profile-photo-fixture.jpg"
        let store = InMemoryProfileStore(photoStore: photoStore)
        let profile = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: filename
        )

        try await store.save(profile)
        try await store.clear()

        let cleared = await photoStore.clearedFilenames
        #expect(cleared == [filename])
        #expect(await store.hasProfile == false)
    }

    @Test func clearWithoutPhotoDoesNotCallPhotoStore() async throws {
        // Sanity check — when the profile has nil `photoFilename` the
        // clear flow shouldn't speculatively call into the photo store.
        let photoStore = InMemoryProfilePhotoStore()
        let store = InMemoryProfileStore(photoStore: photoStore)
        let profile = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com"
        )

        try await store.save(profile)
        try await store.clear()

        let cleared = await photoStore.clearedFilenames
        #expect(cleared.isEmpty)
        let clearedOriginals = await photoStore.clearedOriginalFilenames
        #expect(clearedOriginals.isEmpty)
    }

    @Test func clearAlsoClearsThePhotoOriginalFile() async throws {
        // T-745 / CL-142 — AC-44.9 amended. ProfileStore.clear() must
        // also call `photoStore.clearOriginal(filename:)` on the
        // current profile's `photoOriginalFilename` so Sign Out +
        // Delete Profile leave both cropped + original on disk in the
        // same clean state. Pinned via the in-memory photo store
        // fake whose `clearedOriginalFilenames` records every call.
        let photoStore = InMemoryProfilePhotoStore()
        let croppedFilename = "profile-photo-fixture.jpg"
        let originalFilename = "profile-photo-original-fixture.jpg"
        let store = InMemoryProfileStore(photoStore: photoStore)
        let profile = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: croppedFilename,
            photoOriginalFilename: originalFilename
        )

        try await store.save(profile)
        try await store.clear()

        let clearedOriginals = await photoStore.clearedOriginalFilenames
        #expect(clearedOriginals == [originalFilename])
        // The cropped path is also cleared (preserves the AC-44.9
        // contract from CL-137 — both files gone after clear()).
        let cleared = await photoStore.clearedFilenames
        #expect(cleared == [croppedFilename])
        #expect(await store.hasProfile == false)
    }

    @Test func legacyProfileWithOnlyCroppedClearsCroppedNotOriginal() async throws {
        // Legacy users persisted before T-745 only have the cropped
        // derivative on disk; their `photoOriginalFilename` is nil.
        // The clear flow should still clean up the cropped file but
        // NOT speculatively call clearOriginal with a nil/empty arg.
        let photoStore = InMemoryProfilePhotoStore()
        let croppedFilename = "profile-photo-legacy.jpg"
        let store = InMemoryProfileStore(photoStore: photoStore)
        let profile = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: croppedFilename
                // photoOriginalFilename intentionally omitted — legacy path.
        )

        try await store.save(profile)
        try await store.clear()

        let cleared = await photoStore.clearedFilenames
        #expect(cleared == [croppedFilename])
        let clearedOriginals = await photoStore.clearedOriginalFilenames
        #expect(clearedOriginals.isEmpty)
    }
    #endif

    @Test func saveWithSeededUUIDPreservesIdentity() async throws {
        // The US-15 guest UUID becomes the Profile.id when wrapping —
        // callers (the composition root + the edit view) pass the
        // existing guest UUID in; the store round-trips it intact so
        // old guest comments stay associated with the same UUID per
        // CL-136 / AC-44.6.
        let guestUUID = UUID()
        let store = InMemoryProfileStore()
        let profile = UserProfile(
            id: guestUUID,
            displayName: "Spencer",
            email: "spencer@example.com"
        )

        try await store.save(profile)
        let loaded = await store.load()

        #expect(loaded?.id == guestUUID)
    }
}
