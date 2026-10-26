import DODDomain
import XCTest

@testable import DODSupport

final class TechniqueMilestonesTests: XCTestCase {

    func testEarnedFromEntries() throws {
        let entries = [
            CookLogEntry(id: UUID(), recipeID: 1, recipeTitle: "Seared Steak", cookedAt: Date()),
            CookLogEntry(id: UUID(), recipeID: 2, recipeTitle: "Seared Steak", cookedAt: Date()),
            CookLogEntry(id: UUID(), recipeID: 3, recipeTitle: "Braised Beef", cookedAt: Date()),
        ]

        let milestones = TechniqueMilestones.earned(from: entries)
        XCTAssertEqual(milestones.count, 1)
        XCTAssertEqual(milestones[0].technique, .sear)
        XCTAssertEqual(milestones[0].reps, 2)
    }

    func testEarnedFromEntriesOnlyOneEntry() throws {
        let entries = [
            CookLogEntry(id: UUID(), recipeID: 1, recipeTitle: "Seared Steak", cookedAt: Date())
        ]

        let milestones = TechniqueMilestones.earned(from: entries)
        XCTAssertEqual(milestones.count, 0)
    }

    func testSummary() throws {
        let milestones = [
            TechniqueMilestone(technique: .sear, reps: 2),
            TechniqueMilestone(technique: .braise, reps: 3),
            TechniqueMilestone(technique: .bake, reps: 4),
        ]

        let summary = TechniqueMilestones.summary(milestones)
        XCTAssertEqual(summary, "You've now seared, braised, and baked in cast iron.")
    }

    func testSummaryEmpty() throws {
        let summary = TechniqueMilestones.summary([])
        XCTAssertNil(summary)
    }
}
