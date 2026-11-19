import DODSupport
import Foundation

/// DUT-1879 — logic layer for the Camp Trip Planner (SwiftUI binds in a follow-up).
@MainActor
@Observable
public final class CampTripPlannerViewModel {
    public private(set) var trip: CampTrip
    public private(set) var ledger: CampFuelLedger
    private let store: CampTripStore
    private let appender: ShoppingListStore?

    public init(
        store: CampTripStore = CampTripStore(),
        shoppingStore: ShoppingListStore? = ShoppingListStore()
    ) {
        self.store = store
        self.appender = shoppingStore
        if let snap = store.load() {
            trip = snap.trip
            ledger = snap.ledger
        } else {
            trip = CampTrip(name: "My Camp Trip", nights: 3)
            ledger = CampFuelLedger(packedBriquettes: 0)
        }
    }

    public var budget: CampFuelBudget.Budget { CampFuelBudget.budget(for: trip) }

    public var isFuelShort: Bool { ledger.isShort(for: budget) }

    public func add(_ meal: CampMeal) {
        trip.meals.append(meal)
        persist()
    }

    public func remove(mealID: UUID) {
        trip.meals.removeAll { $0.id == mealID }
        persist()
    }

    /// Pack exactly the planned budget.
    public func packPlannedFuel() {
        ledger.packedBriquettes = budget.totalBriquettes
        persist()
    }

    public func recordUsed(_ briquettes: Int, for mealID: UUID) {
        ledger.recordUsed(briquettes, for: mealID)
        persist()
    }

    /// Sends the consolidated pack list to the Bring List store; returns appended count.
    @discardableResult
    public func sendToPackList() -> Int {
        appender?.append(rows: CampTripPackList.rows(for: trip)) ?? 0
    }

    private func persist() {
        store.save(.init(trip: trip, ledger: ledger))
    }
}
