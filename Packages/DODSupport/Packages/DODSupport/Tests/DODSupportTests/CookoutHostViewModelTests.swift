import Foundation
import Testing

@testable import DODSupport

@Suite("CookoutHostViewModel") struct CookoutHostViewModelTests {

    func freshDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: UUID().uuidString) else {
            fatalError("Failed to create UserDefaults with suite name")
        }
        return defaults
    }

    @Test func startPlanThenAddDishTwiceWithSameRecipeIDLeavesOneDish() {
        let defaults = freshDefaults()
        let store = CookoutPlanStore(defaults: defaults)
        let viewModel = CookoutHostViewModel(store: store)

        let dish1 = CookoutPlan.Dish(recipeID: 1, title: "Chili", sourceServings: 6, cookMinutes: 90)
        let dish2 = CookoutPlan.Dish(recipeID: 1, title: "Chili", sourceServings: 6, cookMinutes: 90)  // Same recipeID

        viewModel.startPlan(name: "Family Cookout", guestCount: 10, serveAt: Date())
        viewModel.addDish(dish1)
        viewModel.addDish(dish2)  // Should not be added due to same recipeID

        #expect(viewModel.plan?.dishes.count == 1)
        #expect(viewModel.plan?.dishes.first?.recipeID == 1)
    }

    @Test func setGuestCountZeroClampsToOne() {
        let defaults = freshDefaults()
        let store = CookoutPlanStore(defaults: defaults)
        let viewModel = CookoutHostViewModel(store: store)

        viewModel.startPlan(name: "Family Cookout", guestCount: 10, serveAt: Date())
        viewModel.setGuestCount(0)

        #expect(viewModel.plan?.guestCount == 1)
    }

    @Test func secondViewModelSeesSavedPlan() {
        let defaults = freshDefaults()
        let store = CookoutPlanStore(defaults: defaults)
        let firstViewModel = CookoutHostViewModel(store: store)

        firstViewModel.startPlan(name: "Family Cookout", guestCount: 10, serveAt: Date())
        firstViewModel.addDish(CookoutPlan.Dish(recipeID: 1, title: "Chili", sourceServings: 6, cookMinutes: 90))

        // Create a second view model with the same defaults
        let secondViewModel = CookoutHostViewModel(store: store)

        #expect(secondViewModel.plan?.name == "Family Cookout")
        #expect(secondViewModel.plan?.guestCount == 10)
        #expect(secondViewModel.plan?.dishes.count == 1)
    }

    @Test func finishReturnsMemoryAndClearsPlan() {
        let defaults = freshDefaults()
        let store = CookoutPlanStore(defaults: defaults)
        let viewModel = CookoutHostViewModel(store: store)

        viewModel.startPlan(name: "Family Cookout", guestCount: 10, serveAt: Date())
        viewModel.addDish(CookoutPlan.Dish(recipeID: 1, title: "Chili", sourceServings: 6, cookMinutes: 90))

        let memory = viewModel.finish(photoFilenames: ["photo.jpg"], reactions: [.loved])

        #expect(memory != nil)
        #expect(viewModel.plan == nil)
        #expect(store.load() == nil)
    }

    @Test func scheduleReturnsEmptyArrayWhenNoPlan() {
        let defaults = freshDefaults()
        let store = CookoutPlanStore(defaults: defaults)
        let viewModel = CookoutHostViewModel(store: store)

        let schedule = viewModel.schedule()

        #expect(schedule.isEmpty)
    }
}
