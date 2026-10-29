import Foundation
import Testing

@testable import DODSupport

@Suite("OneBiteStats (DUT-996)")
struct OneBiteStatsTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = 12
        guard let date = calendar.date(from: dateComponents) else {
            fatalError("Failed to create date for \(year)-\(month)-\(day)")
        }
        return date
    }

    private func e(
        _ key: String = "jake",
        _ recipeID: Int,
        _ reaction: OneBiteReaction,
        _ at: Date
    ) -> DinerReactionEntry {
        DinerReactionEntry(
            dinerKey: key,
            dinerName: "Jake",
            recipeID: recipeID,
            recipeTitle: "R\(recipeID)",
            reaction: reaction,
            loggedAt: at
        )
    }

    @Test("countsDistinctRecipesThisMonthOnly")
    func countsDistinctRecipesThisMonthOnly() {
        let entries = [
            e("jake", 1, .tried, date(2026, 3, 5)),
            e("jake", 1, .tried, date(2026, 3, 6)),
            e("jake", 2, .liked, date(2026, 3, 10)),
            e("jake", 3, .notYet, date(2026, 3, 15)),
            e("jake", 4, .tried, date(2026, 2, 20)),
        ]

        let result = OneBiteStats.newThingsTried(
            dinerKey: "jake",
            in: entries,
            asOf: date(2026, 3, 20),
            calendar: calendar
        )

        #expect(result == 2)
    }

    @Test("ignoresOtherDiners")
    func ignoresOtherDiners() {
        let entries = [
            e("jake", 1, .tried, date(2026, 3, 5)),
            e("mia", 1, .tried, date(2026, 3, 10)),
        ]

        let jakeResult = OneBiteStats.newThingsTried(
            dinerKey: "jake",
            in: entries,
            asOf: date(2026, 3, 20),
            calendar: calendar
        )

        let miaResult = OneBiteStats.newThingsTried(
            dinerKey: "mia",
            in: entries,
            asOf: date(2026, 3, 20),
            calendar: calendar
        )

        #expect(jakeResult == 1)
        #expect(miaResult == 1)
    }

    @Test("headlineSingularPluralAndNil")
    func headlineSingularPluralAndNil() {
        let now = date(2026, 3, 20)

        // With no entries, expect nil
        #expect(
            OneBiteStats.monthlyHeadline(
                dinerKey: "jake",
                dinerName: "Jake",
                in: [],
                asOf: now,
                calendar: calendar
            ) == nil
        )

        // With one .tried entry for recipe 1 in March, expect "Jake's tried 1 new thing this month."
        let singleEntry = [e("jake", 1, .tried, date(2026, 3, 5))]
        #expect(
            OneBiteStats.monthlyHeadline(
                dinerKey: "jake",
                dinerName: "Jake",
                in: singleEntry,
                asOf: now,
                calendar: calendar
            ) == "Jake's tried 1 new thing this month."
        )

        // With a second entry for recipe 2 added, expect "Jake's tried 2 new things this month."
        let twoEntries = [
            e("jake", 1, .tried, date(2026, 3, 5)),
            e("jake", 2, .tried, date(2026, 3, 10)),
        ]
        #expect(
            OneBiteStats.monthlyHeadline(
                dinerKey: "jake",
                dinerName: "Jake",
                in: twoEntries,
                asOf: now,
                calendar: calendar
            ) == "Jake's tried 2 new things this month."
        )
    }
}
