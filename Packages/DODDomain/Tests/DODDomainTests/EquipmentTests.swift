import Foundation
import Testing

@testable import DODDomain

@Suite("Equipment")
struct EquipmentTests {

    @Test func optionalURLsDefaultToNil() {
        let item = Equipment(name: "Dutch oven")
        #expect(item.name == "Dutch oven")
        #expect(item.imageURL == nil)
        #expect(item.link == nil)
    }

    @Test func initStoresAllFields() throws {
        let id = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let image = try #require(URL(string: "https://example.com/oven.jpg"))
        let link = try #require(URL(string: "https://example.com/buy"))
        let item = Equipment(id: id, name: "Lid lifter", imageURL: image, link: link)
        #expect(item.id == id)
        #expect(item.imageURL == image)
        #expect(item.link == link)
    }

    @Test func eachDefaultInitGetsAFreshID() {
        let first = Equipment(name: "Tongs")
        let second = Equipment(name: "Tongs")
        #expect(first.id != second.id)
    }

    @Test func emptyNameIsKept() {
        #expect(Equipment(name: "").name.isEmpty)
    }

    @Test func equalWhenAllFieldsIncludingIDMatch() throws {
        let id = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let first = Equipment(id: id, name: "Tongs")
        let second = Equipment(id: id, name: "Tongs")
        #expect(first == second)
    }

    @Test func notEqualWhenOnlyTheIDDiffers() {
        #expect(Equipment(name: "Tongs") != Equipment(name: "Tongs"))
    }

    @Test func notEqualWhenTheLinkDiffers() throws {
        let id = try #require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let link = try #require(URL(string: "https://example.com/a"))
        #expect(Equipment(id: id, name: "X") != Equipment(id: id, name: "X", link: link))
    }

    @Test func identifiableIDIsTheUUID() {
        let item = Equipment(name: "Trivet")
        #expect(item.id == item.id)
        let identified: any Identifiable = item
        #expect(identified.id as? UUID == item.id)
    }

    @Test func setDeduplicatesIdenticalValues() throws {
        let id = try #require(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let set: Set<Equipment> = [
            Equipment(id: id, name: "Trivet"),
            Equipment(id: id, name: "Trivet"),
            Equipment(name: "Trivet"),
        ]
        #expect(set.count == 2)
    }
}
