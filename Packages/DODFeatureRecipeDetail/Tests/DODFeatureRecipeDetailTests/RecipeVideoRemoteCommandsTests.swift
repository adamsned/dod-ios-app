import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("RecipeVideoRemoteCommands (DUT-1013)")
struct RecipeVideoRemoteCommandsTests {

    @Test("skipTarget tests")
    func skipTargetTests() {
        // A skip forward from 10 with delta 15 and duration 100 gives 25.
        #expect(RecipeVideoRemoteCommands.skipTarget(current: 10, delta: 15, duration: 100) == 25)

        // A skip back from 5 with delta -15 gives 0.
        #expect(RecipeVideoRemoteCommands.skipTarget(current: 5, delta: -15, duration: 100) == 0)

        // A skip forward from 95 with delta 15 and duration 100 gives 100.
        #expect(RecipeVideoRemoteCommands.skipTarget(current: 95, delta: 15, duration: 100) == 100)

        // A skip forward with duration nil is not capped.
        #expect(RecipeVideoRemoteCommands.skipTarget(current: 95, delta: 15, duration: nil) == 110)
    }
}
