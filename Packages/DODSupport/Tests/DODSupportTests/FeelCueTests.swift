import Foundation
import Testing

@testable import DODSupport

@Suite("FeelCue") struct FeelCueTests {

    private let base = FeelCue(title: "Sound", onTrack: "Steady sizzle.", adjust: "Pull coals.")

    @Test func initStoresEveryField() {
        #expect(base.title == "Sound")
        #expect(base.onTrack == "Steady sizzle.")
        #expect(base.adjust == "Pull coals.")
    }

    @Test func idIsTheTitle() {
        #expect(base.id == "Sound")
    }

    @Test func equalWhenAllFieldsMatch() {
        let same = FeelCue(title: "Sound", onTrack: "Steady sizzle.", adjust: "Pull coals.")
        #expect(base == same)
    }

    @Test func notEqualWhenAnyFieldDiffers() {
        #expect(base != FeelCue(title: "Smell", onTrack: "Steady sizzle.", adjust: "Pull coals."))
        #expect(base != FeelCue(title: "Sound", onTrack: "Loud.", adjust: "Pull coals."))
        #expect(base != FeelCue(title: "Sound", onTrack: "Steady sizzle.", adjust: "Wait."))
    }

    @Test func emptyStringsAreAllowed() {
        let empty = FeelCue(title: "", onTrack: "", adjust: "")
        #expect(empty.id == "")
    }
}