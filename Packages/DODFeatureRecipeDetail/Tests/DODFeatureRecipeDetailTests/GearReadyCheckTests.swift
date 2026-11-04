import DODDomain
import Foundation
import SwiftUI
import Testing

@testable import DODFeatureRecipeDetail

struct GearReadyCheckTests {
    @Test
    func isNeededFalseWhenEmpty() {
        #expect(GearReadyCheck(items: []).isNeeded == false)
    }

    @Test
    func isNeededTrueWithOneItem() {
        let check = GearReadyCheck(items: [Equipment(name: "Dutch oven")])
        #expect(check.isNeeded)
    }

    @Test
    func toggleTwiceReturnsToZero() {
        let item = Equipment(name: "Trivet")
        var check = GearReadyCheck(items: [item])
        check.toggle(item)
        #expect(check.has(item))
        #expect(check.haveCount == 1)
        check.toggle(item)
        #expect(check.has(item) == false)
        #expect(check.haveCount == 0)
    }

    @Test
    func isCompleteAfterTogglingAll() {
        let items = [Equipment(name: "Tongs"), Equipment(name: "Chimney starter")]
        var check = GearReadyCheck(items: items)
        #expect(check.isComplete == false)
        for item in items { check.toggle(item) }
        #expect(check.isComplete)
    }

    @Test
    func lidLifterTipMentionsTongs() {
        let tip = GearReadyCheck.substitutionTip(for: "Lid Lifter")
        #expect(tip?.contains("Tongs") == true)
    }

    @Test
    func unknownToolHasNoTip() {
        #expect(GearReadyCheck.substitutionTip(for: "Whisk") == nil)
    }

    @MainActor
    @Test
    func initBuildsView() {
        let view = GearReadyCheckView(
            equipment: [Equipment(name: "Lid Lifter")],
            onStart: {},
            onCancel: {}
        )
        _ = view
    }
}
