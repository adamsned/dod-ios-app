import Foundation
import Testing

@testable import DODSupport

@Suite("TonightsRungSnapshot") struct TonightsRungSnapshotTests {

    private static func freshDefaults() throws -> UserDefaults {
        let name = "dod.widget.tonightsrung.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func sampleCook() -> TonightsRungSnapshot {
        TonightsRungSnapshot(
            writtenAt: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .cook,
            recipeID: 7,
            title: "Chili",
            stepNumber: nil
        )
    }

    private static func sampleResume() -> TonightsRungSnapshot {
        TonightsRungSnapshot(
            writtenAt: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .resume,
            recipeID: 7,
            title: "Chili",
            stepNumber: 3
        )
    }

    @Test func writeThenReadRoundTrips() throws {
        let store = WidgetSnapshotStore(defaults: try Self.freshDefaults())
        let snap = Self.sampleCook()
        try store.writeTonightsRung(snap)
        #expect(store.readTonightsRung() == snap)
    }

    @Test func readReturnsNilWhenSchemaVersionMismatches() throws {
        let store = WidgetSnapshotStore(defaults: try Self.freshDefaults())
        let base = Self.sampleCook()
        let bad = TonightsRungSnapshot(
            schemaVersion: TonightsRungSnapshot.currentSchemaVersion + 1,
            writtenAt: base.writtenAt,
            kind: base.kind,
            recipeID: base.recipeID,
            title: base.title,
            stepNumber: base.stepNumber
        )
        try store.writeTonightsRung(bad)
        #expect(store.readTonightsRung() == nil)
    }

    @Test func readReturnsNilWhenNothingWritten() throws {
        let store = WidgetSnapshotStore(defaults: try Self.freshDefaults())
        #expect(store.readTonightsRung() == nil)
    }

    @Test func labelForCook() {
        let snap = Self.sampleCook()
        #expect(snap.label == "Cook: Chili")
    }

    @Test func labelForResume() {
        let snap = Self.sampleResume()
        #expect(snap.label == "Continue: Step 3 of Chili")
    }

    @Test func deepLinkIntentIsStartCookMode() {
        let snap = Self.sampleCook()
        #expect(snap.deepLinkIntent == .startCookMode(recipeID: 7))
    }
}
