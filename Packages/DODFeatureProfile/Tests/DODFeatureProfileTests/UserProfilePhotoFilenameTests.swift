import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage extending Phase a's ``UserProfileValidationTests`` to pin
/// the ``UserProfile/photoFilename`` Codable round-trip — both the
/// default-nil branch and the populated branch. Phase a's contract was
/// "photoFilename can be nil"; Phase b adds the populated round-trip
/// guarantee so the Keychain JSON survives the photo flow without
/// silently dropping the filename.
///
/// Spec trace: US-44 AC-44.3, AC-44.8, AC-44.9; CL-137.
@Suite("UserProfile photoFilename (T-740)")
struct UserProfilePhotoFilenameTests {

    // MARK: - Defaults

    @Test func photoFilenameDefaultsToNil() {
        // Init without the parameter — Phase a stub behavior preserved.
        let profile = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com"
        )
        #expect(profile.photoFilename == nil)
    }

    // MARK: - Codable round-trip

    @Test func codableRoundTripPreservesNilPhotoFilename() throws {
        let original = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

        #expect(decoded.photoFilename == nil)
        #expect(decoded == original)
    }

    @Test func codableRoundTripPreservesPopulatedPhotoFilename() throws {
        // Matches the production filename shape (`profile-photo-<UUID>.jpg`)
        // so the round-trip exercises the realistic on-disk identifier.
        let filename = "profile-photo-" + UUID().uuidString + ".jpg"
        let original = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: filename
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

        #expect(decoded.photoFilename == filename)
        #expect(decoded == original)
    }

    @Test func equatableTreatsPhotoFilenameAsLoadBearing() {
        // Sanity check that the auto-synthesized Equatable doesn't ignore
        // the new field — otherwise a "no-op" Replace flow would surface
        // as a silent equal-to-original failure on the dirty-form check.
        let id = UUID()
        let withPhoto = UserProfile(
            id: id,
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: "profile-photo-1.jpg"
        )
        let withoutPhoto = UserProfile(
            id: id,
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: nil
        )
        #expect(withPhoto != withoutPhoto)
    }

    // MARK: - photoOriginalFilename (T-745 / CL-142)

    @Test func photoOriginalFilenameDefaultsToNil() {
        // Init without the parameter — T-745 / CL-142 is opt-in; older
        // call sites that don't pass `photoOriginalFilename` get nil.
        let profile = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com"
        )
        #expect(profile.photoOriginalFilename == nil)
    }

    @Test func codableRoundTripPreservesNilPhotoOriginalFilename() throws {
        let original = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

        #expect(decoded.photoOriginalFilename == nil)
        #expect(decoded == original)
    }

    @Test func codableRoundTripPreservesPopulatedPhotoOriginalFilename() throws {
        let original = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: "profile-photo-" + UUID().uuidString + ".jpg",
            photoOriginalFilename: "profile-photo-original-" + UUID().uuidString + ".jpg"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

        #expect(decoded.photoOriginalFilename == original.photoOriginalFilename)
        #expect(decoded == original)
    }

    @Test func legacyJSONWithoutPhotoOriginalFilenameDecodesToNil() throws {
        // Legacy profiles persisted before T-745 won't have the
        // `photoOriginalFilename` key in their JSON. The auto-synthesized
        // Codable for optionals uses `decodeIfPresent` semantics so the
        // missing key decodes to nil rather than throwing. Pin that the
        // legacy Keychain row decodes cleanly into the new struct shape.
        let legacyJSON = """
            {
                "id": "12345678-1234-1234-1234-123456789012",
                "displayName": "Spencer",
                "email": "spencer@example.com",
                "photoFilename": "profile-photo-legacy.jpg"
            }
            """
        guard let data = legacyJSON.data(using: .utf8) else {
            Issue.record("Test fixture data conversion failed")
            return
        }
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

        #expect(decoded.displayName == "Spencer")
        #expect(decoded.email == "spencer@example.com")
        #expect(decoded.photoFilename == "profile-photo-legacy.jpg")
        #expect(decoded.photoOriginalFilename == nil)
    }

    @Test func equatableTreatsPhotoOriginalFilenameAsLoadBearing() {
        // The dirty-form check (CL-140 / AC-44.16) only compares the
        // cropped photoFilename today, but the Equatable conformance
        // still has to see the original field as load-bearing for the
        // Codable round-trip + future surface evolution. Belt-and-
        // suspenders parallel to the cropped equivalent test above.
        let id = UUID()
        let withOriginal = UserProfile(
            id: id,
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: "profile-photo-1.jpg",
            photoOriginalFilename: "profile-photo-original-1.jpg"
        )
        let withoutOriginal = UserProfile(
            id: id,
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: "profile-photo-1.jpg",
            photoOriginalFilename: nil
        )
        #expect(withOriginal != withoutOriginal)
    }
}
