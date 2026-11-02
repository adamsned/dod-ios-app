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
        #expect(empty.id.isEmpty)
    }

    @Test func shippedCuesHaveUniqueIDs() {
        let ids = DutchOvenHeatCoach.feelCues.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func shippedCueIDsEqualTheirTitles() {
        for cue in DutchOvenHeatCoach.feelCues {
            #expect(cue.id == cue.title)
        }
    }

    @Test func shippedCuesCanKeyADictionaryWithoutCollision() {
        let byID = Dictionary(
            uniqueKeysWithValues: DutchOvenHeatCoach.feelCues.map { ($0.id, $0) }
        )
        #expect(byID.count == DutchOvenHeatCoach.feelCues.count)
        #expect(byID["Hand Test"]?.title == "Hand Test")
    }
}
