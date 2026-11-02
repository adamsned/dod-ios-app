import Foundation
import Testing

@testable import DODSupport

struct ServingsScaleRequestTests {
    @Test func servingsParsedOnlyForMatchingRecipe() {
        let note = Notification(
            name: .dodServingsScaleRequested,
            object: 7,
            userInfo: ["servings": 12]
        )
        #expect(ServingsScaleRequest.servings(from: note, forRecipeID: 7) == 12)
        #expect(ServingsScaleRequest.servings(from: note, forRecipeID: 8) == nil)
    }
}
