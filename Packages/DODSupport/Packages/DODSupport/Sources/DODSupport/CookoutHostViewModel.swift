import Foundation

/// DUT-965 — state holder for Cookout Host Mode.
public final class CookoutHostViewModel {
    public private(set) var plan: CookoutPlan?
    public private(set) var memory: CookoutMemory?
    private let store: CookoutPlanStore

    public init(store: CookoutPlanStore = CookoutPlanStore()) {
        self.store = store
        self.plan = store.load()
    }

    public func startPlan(name: String, guestCount: Int, serveAt: Date) {
        let new = CookoutPlan(name: name, guestCount: guestCount, serveAt: serveAt)
        plan = new
        store.save(new)
    }

    public func addDish(_ dish: CookoutPlan.Dish) {
        guard var current = plan, !current.dishes.contains(where: { $0.recipeID == dish.recipeID }) else { return }
        current.dishes.append(dish)
        plan = current
        store.save(current)
    }

    public func setGuestCount(_ count: Int) {
        guard var current = plan else { return }
        current.guestCount = max(1, count)
        plan = current
        store.save(current)
    }

    public func schedule() -> [CookoutScheduler.Entry] {
        plan.map(CookoutScheduler.schedule(for:)) ?? []
    }

    public func guestMenu(now: Date) -> GuestMenuSnapshot? {
        plan.map { GuestMenuSnapshot.make(from: $0, now: now) }
    }

    /// Ends the cookout: builds the memory and clears the saved plan.
    @discardableResult
    public func finish(photoFilenames: [String], reactions: [CookoutMemory.Reaction]) -> CookoutMemory? {
        guard let current = plan else { return nil }
        let made = CookoutMemory(plan: current, photoFilenames: photoFilenames, reactions: reactions)
        memory = made
        plan = nil
        store.clear()
        return made
    }
}
