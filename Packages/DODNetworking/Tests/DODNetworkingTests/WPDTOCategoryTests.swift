import Foundation
import Testing

@testable import DODNetworking

@Suite("WPDTO.Category description (DUT-2148)") struct WPDTOCategoryTests {
    @Test("Description is decoded and sanitized to plain text")
    func decodesAndSanitizesDescription() throws {
        let json = """
            {"id":5,"name":"Camping","slug":"camping","count":3,\
            "description":"<p>Fire &amp; smoke</p>"}
            """
        let dto = try JSONDecoder().decode(WPDTO.Category.self, from: Data(json.utf8))
        let domain = dto.toDomain()
        #expect(domain.description.contains("Fire"))
        #expect(!domain.description.contains("<p>"))
    }

    @Test("Missing description maps to an empty string")
    func missingDescriptionIsEmpty() throws {
        let json = #"{"id":5,"name":"Camping","slug":"camping","count":3}"#
        let dto = try JSONDecoder().decode(WPDTO.Category.self, from: Data(json.utf8))
        #expect(dto.toDomain().description.isEmpty)
    }
}
