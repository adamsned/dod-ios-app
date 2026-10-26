import Foundation
import Testing

@testable import DODDomain

@Suite("RecipeInstruction image (DUT-170)")
struct RecipeInstructionImageTests {
    @Test("defaultsToNilImage")
    func defaultsToNilImage() {
        #expect(RecipeInstruction(step: 1, text: "x").imageURL == nil)
    }

    @Test("decodesLegacyJSONWithoutImageKey")
    func decodesLegacyJSONWithoutImageKey() throws {
        let json = """
            {"id":"00000000-0000-0000-0000-000000000001","step":1,"text":"x"}
            """
        guard let jsonData = json.data(using: .utf8) else {
            Issue.record("Failed to create JSON data")
            return
        }
        let data = try JSONSerialization.jsonObject(with: jsonData)
        let decoder = JSONDecoder()
        let instruction = try decoder.decode(RecipeInstruction.self, from: jsonData)
        #expect(instruction.imageURL == nil)
    }

    @Test("roundTripsImageURL")
    func roundTripsImageURL() throws {
        let url = URL(string: "https://e.com/a.jpg")!
        let instruction = RecipeInstruction(step: 1, text: "x", imageURL: url)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(instruction)
        let decoded = try decoder.decode(RecipeInstruction.self, from: data)
        #expect(decoded.imageURL == url)
    }
}
