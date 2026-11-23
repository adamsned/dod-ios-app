import Foundation
import SwiftData
import Testing

@testable import DODPersistence

@Suite("SyncedMealPlanEntry (DUT-103)")
struct SyncedMealPlanEntryTests {
    @Test func roundTripsInMemory() throws {
        let container = try ModelContainer(
            for: SyncedMealPlanEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(
            SyncedMealPlanEntry(recipeID: 42, recipeTitle: "Stew", day: .now, slotRaw: "lunch")
        )
        try context.save()
        let rows = try context.fetch(FetchDescriptor<SyncedMealPlanEntry>())
        #expect(rows.count == 1)
        #expect(rows.first?.recipeID == 42)
        #expect(rows.first?.slotRaw == "lunch")
    }
}
