import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// US-51 / AC-51.1: decode the WP Recipe Maker recipe-card `equipment`
/// array into `[DODDomain.Equipment]`, degrading gracefully when the field
/// is absent, empty, or partially malformed.
@Suite("WPRM equipment parse (AC-51.1)") struct WPRMEquipmentParseTests {

    private func decodeCard(_ json: String) throws -> WPDTO.RecipeCard {
        try JSONDecoder().decode(WPDTO.RecipeCard.self, from: Data(json.utf8))
    }

    @Test func parsesNamesLinksAndImages() throws {
        let json = #"""
            {
              "equipment": [
                {
                  "name": "12\" Camp Dutch Oven",
                  "link": "https://shop.example.com/oven",
                  "image_url": "https://img.example.com/oven.jpg"
                },
                { "name": "Chimney Starter", "link": "https://shop.example.com/chimney" }
              ]
            }
            """#
        let card = try decodeCard(json)
        let equipment = card.equipmentList

        #expect(equipment.count == 2)
        #expect(equipment.map(\.name) == ["12\" Camp Dutch Oven", "Chimney Starter"])
        #expect(equipment[0].link == URL(string: "https://shop.example.com/oven"))
        #expect(equipment[0].imageURL == URL(string: "https://img.example.com/oven.jpg"))
        // Second entry omits image_url → nil, not a decode failure.
        #expect(equipment[1].link == URL(string: "https://shop.example.com/chimney"))
        #expect(equipment[1].imageURL == nil)
    }

    @Test func absentEquipmentYieldsEmpty() throws {
        // A card with no `equipment` key at all (the common case).
        let card = try decodeCard(#"{ "name": "Some Recipe" }"#)
        #expect(card.equipmentList.isEmpty)
    }

    @Test func emptyEquipmentArrayYieldsEmpty() throws {
        let card = try decodeCard(#"{ "equipment": [] }"#)
        #expect(card.equipmentList.isEmpty)
    }

    @Test func skipsEntriesWithoutAUsableName() throws {
        // Mix of: blank name, missing name, whitespace-only name, and one good
        // entry. Only the good one survives — no crash, no thrown error.
        let json = #"""
            {
              "equipment": [
                { "name": "", "link": "https://example.com/a" },
                { "link": "https://example.com/b" },
                { "name": "   " },
                { "name": "Cast-Iron Trivet" }
              ]
            }
            """#
        let equipment = try decodeCard(json).equipmentList
        #expect(equipment.count == 1)
        #expect(equipment.first?.name == "Cast-Iron Trivet")
    }

    @Test func emptyOrBlankURLsCollapseToNilButKeepEntry() throws {
        // Empty and whitespace-only URL strings must not drop the entry; the
        // name is still useful, the URLs just become nil.
        let json = #"""
            {
              "equipment": [
                { "name": "Lid Lifter", "link": "", "image_url": "   " },
                { "name": "Heat Gloves", "link": "  ", "image_url": "" }
              ]
            }
            """#
        let equipment = try decodeCard(json).equipmentList
        #expect(equipment.count == 2)
        #expect(equipment[0].name == "Lid Lifter")
        #expect(equipment[0].link == nil)
        #expect(equipment[0].imageURL == nil)
        #expect(equipment[1].name == "Heat Gloves")
        #expect(equipment[1].link == nil)
        #expect(equipment[1].imageURL == nil)
    }

    @Test func stripsHTMLFromEquipmentName() throws {
        let json = #"""
            { "equipment": [ { "name": "Dutch &amp; Oven <strong>Lid</strong>" } ] }
            """#
        let equipment = try decodeCard(json).equipmentList
        #expect(equipment.count == 1)
        #expect(equipment.first?.name == "Dutch & Oven Lid")
    }
}
