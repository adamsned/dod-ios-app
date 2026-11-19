import XCTest

@testable import DODSupport

final class DietaryProfileTests: XCTestCase {
    func testEmptyDietaryProfile() {
        let profile = DietaryProfile()
        XCTAssertTrue(profile.isEmpty)
        XCTAssertFalse(profile.onlyShowFitting)
    }

    func testDietaryProfileRoundTrip() throws {
        let originalProfile = DietaryProfile(
            patterns: [.vegan],
            allergens: [.nuts],
            onlyShowFitting: true
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(originalProfile)
        let decodedProfile = try decoder.decode(DietaryProfile.self, from: data)

        XCTAssertEqual(decodedProfile, originalProfile)
    }
}
