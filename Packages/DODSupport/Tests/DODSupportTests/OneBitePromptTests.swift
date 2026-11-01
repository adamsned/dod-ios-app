import DODSupport
import Testing

@Suite("OneBitePrompt (DUT-996)")
struct OneBitePromptTests {

    @Test("goalNamesTheDinerAndOneBite")
    func goalNamesTheDinerAndOneBite() {
        let prompt = OneBitePrompt.make(dinerName: "Jake", recipeTitle: "Beef Chili")
        #expect(prompt.goal.contains("Jake"))
        #expect(prompt.goal.contains("one bite"))
    }

    @Test("chiliGetsCornbreadPairing")
    func chiliGetsCornbreadPairing() {
        let prompt = OneBitePrompt.make(dinerName: "Jake", recipeTitle: "Beef Chili")
        #expect(prompt.pairing.contains("cornbread"))
    }

    @Test("unknownTitleUsesFallback")
    func unknownTitleUsesFallback() {
        let prompt = OneBitePrompt.make(dinerName: "Jake", recipeTitle: "Mystery Dish")
        #expect(prompt.pairing.starts(with: "Put one small bite"))
    }
}
