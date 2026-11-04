import Testing

@testable import DODIntelligence

struct MomentCaptionPromptTests {
    @Test
    func promptIncludesTitleRatingAndNote() {
        let request = MomentCaptionRequest(
            recipeTitle: "Skillet Cornbread",
            note: "Crispy edges",
            personalRating: 3
        )
        let prompt = LiveDODIntelligenceService.momentCaptionPrompt(for: request)

        #expect(prompt.contains("Dish: Skillet Cornbread"))
        #expect(prompt.contains("3 of 5"))
        #expect(prompt.contains("Crispy edges"))
    }

    @Test
    func promptOmitsBlankNoteAndRating() {
        let request = MomentCaptionRequest(
            recipeTitle: "Skillet Cornbread",
            note: "  ",
            personalRating: nil
        )
        let prompt = LiveDODIntelligenceService.momentCaptionPrompt(for: request)

        #expect(!prompt.contains("note:"))
        #expect(!prompt.localizedCaseInsensitiveContains("rating"))
    }

    @Test
    func promptCapsLongNote() {
        let longNote = String(repeating: "a", count: 5000)
        let request = MomentCaptionRequest(
            recipeTitle: "Skillet Cornbread",
            note: longNote,
            personalRating: nil
        )
        let prompt = LiveDODIntelligenceService.momentCaptionPrompt(for: request)

        #expect(prompt.count < 1200)
    }
}
