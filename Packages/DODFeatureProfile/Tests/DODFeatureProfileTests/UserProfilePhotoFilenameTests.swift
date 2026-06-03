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
}
