import Foundation
import Testing

@testable import DODFeatureProfile

/// DUT-982 — pins the optional `ownedEquipment` field on ``UserProfile``.
@Suite("UserProfile ownedEquipment (DUT-982)")
struct UserProfileEquipmentTests {

    @Test func legacyJSONWithoutEquipmentDecodes() throws {
        let json = """
            {"id":"12345678-1234-1234-1234-123456789012","displayName":"A","email":"a@b.co"}
            """
        let data = Data(json.utf8)
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)
        #expect(profile.ownedEquipment == nil)
    }

    @Test func equipmentRoundTrips() throws {
        let original = UserProfile(
            id: UUID(),
            displayName: "A",
            email: "a@b.co",
            ownedEquipment: ["dutch-oven-12", "cast-iron-10"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        #expect(decoded.ownedEquipment == ["dutch-oven-12", "cast-iron-10"])
        #expect(decoded == original)
    }
}
