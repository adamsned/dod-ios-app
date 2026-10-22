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
        #expect(Equipment(name: "").name == "")
    }
}