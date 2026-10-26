import Testing

@testable import DODIntelligence

@Suite("TripPlanning")
struct TripPlanningTests {
    @Test func slotCountIsDaysTimesMeals() {
        #expect(TripPlanConstraints(headcount: 6, days: 3, mealsPerDay: 2).slotCount == 6)
    }
    @Test func clampsNonPositiveInputs() {
        let constraints = TripPlanConstraints(headcount: 0, days: 0, mealsPerDay: -1)
        #expect(constraints.headcount == 1 && constraints.slotCount == 1)
    }
}
