import Testing

@testable import DODFeatureRecipeDetail

@Suite struct GuestReactionDraftTests {

    @Test func emptyDraftIsInvalid() {
        #expect(GuestReactionDraft().isValid == false)
    }

    @Test func quoteOnlyIsInvalid() {
        var draft = GuestReactionDraft()
        draft.quote = "This was amazing"
        #expect(draft.isValid == false)
    }

    @Test func quoteAndGuestNameIsValid() {
        var draft = GuestReactionDraft()
        draft.quote = "This was amazing"
        draft.guestName = "Aunt May"
        #expect(draft.isValid)
    }

    @Test func zeroRatingSendsNil() {
        var draft = GuestReactionDraft()
        draft.rating = 0
        #expect(draft.ratingToSend == nil)
    }

    @Test func fourStarRatingSendsFour() {
        var draft = GuestReactionDraft()
        draft.rating = 4
        #expect(draft.ratingToSend == 4)
    }
}
