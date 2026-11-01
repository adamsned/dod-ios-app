import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

@MainActor @Suite struct CampTripPlannerViewModelTests {

    private func makeDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: name) else { fatalError("suite") }
        return suite
    }

    private func meal(_ title: String, ingredients: [String] = []) -> CampMeal {
        CampMeal(
            day: 0,
            recipeTitle: title,
            ovenTempF: 350,
            ovenDiameterInches: 12,
            task: .bake,
            ingredients: ingredients
        )
    }

    private func makeVM(defaults: UserDefaults, shopping: Bool = true) -> CampTripPlannerViewModel {
        CampTripPlannerViewModel(
            store: CampTripStore(defaults: defaults),
            shoppingStore: shopping ? ShoppingListStore(defaults: makeDefaults()) : nil
        )
    }

    @Test func threeMealsBudget72() {
        let vm = makeVM(defaults: makeDefaults())
        vm.add(meal("A"))
        vm.add(meal("B"))
        vm.add(meal("C"))
        #expect(vm.budget.totalBriquettes == 72)
    }

    @Test func usedLeavesRemaining48() {
        let vm = makeVM(defaults: makeDefaults())
        let first = meal("A")
        vm.add(first)
        vm.add(meal("B"))
        vm.add(meal("C"))
        vm.packPlannedFuel()
        vm.recordUsed(24, for: first.id)
        #expect(vm.ledger.remaining == 48)
        #expect(!vm.isFuelShort)
    }

    @Test func shortWhenPacked24AllCooked() {
        let suite = makeDefaults()
        let m1 = meal("A")
        let m2 = meal("B")
        CampTripStore(defaults: suite).save(
            .init(
                trip: CampTrip(name: "T", nights: 3, meals: [m1, m2]),
                ledger: CampFuelLedger(packedBriquettes: 24)
            )
        )
        let vm = makeVM(defaults: suite)
        vm.add(meal("C"))
        #expect(vm.isFuelShort == true)
    }

    @Test func restoresTripFromSameStore() {
        let suite = makeDefaults()
        let vm1 = makeVM(defaults: suite)
        vm1.add(meal("A"))
        let vm2 = makeVM(defaults: suite)
        #expect(vm2.trip.meals.count == 1)
    }

    @Test func sendToPackListCountsRowsPlusFuel() {
        let vm = makeVM(defaults: makeDefaults())
        vm.add(meal("A", ingredients: ["1 cup flour", "2 eggs"]))
        #expect(vm.sendToPackList() == 3)
    }

    @Test func sendToPackListNilStoreReturnsZero() {
        let vm = makeVM(defaults: makeDefaults(), shopping: false)
        vm.add(meal("A", ingredients: ["1 cup flour", "2 eggs"]))
        #expect(vm.sendToPackList() == 0)
    }
}
