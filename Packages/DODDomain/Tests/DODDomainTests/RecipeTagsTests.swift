import Foundation
import Testing

@testable import DODDomain

@Suite("RecipeTags value type") struct RecipeTagsTests {

    @Test func codableRoundTrip() throws {
        let original = RecipeTags(
            difficulty: .advanced,
            techniques: [.braise, .sear],
            occasions: [.holiday]
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecipeTags.self, from: encoded)
        #expect(decoded == original)
    }

    @Test func defaultSourceIsAuto() {
        #expect(RecipeTags(difficulty: .beginner).source == .auto)
    }

    @Test func unknownRawValueFailsToDecode() {
        let json = Data(
            #"{"difficulty":"expert","techniques":[],"occasions":[],"source":"auto"}"#.utf8
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RecipeTags.self, from: json)
        }
    }
}
