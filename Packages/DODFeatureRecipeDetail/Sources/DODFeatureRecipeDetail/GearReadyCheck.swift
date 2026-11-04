import DODDomain
import Foundation

/// DUT-984 — pure state for the pre-Cook-Mode gear checklist.
struct GearReadyCheck: Equatable {
    let items: [Equipment]
    private(set) var haveIDs: Set<UUID> = []

    init(items: [Equipment]) {
        self.items = items
    }

    /// The gate only shows when the recipe lists equipment.
    var isNeeded: Bool { !items.isEmpty }
    var haveCount: Int { haveIDs.count }
    var isComplete: Bool { haveIDs.count == items.count }

    func has(_ item: Equipment) -> Bool {
        haveIDs.contains(item.id)
    }

    mutating func toggle(_ item: Equipment) {
        if haveIDs.contains(item.id) {
            haveIDs.remove(item.id)
        } else {
            haveIDs.insert(item.id)
        }
    }

    /// First-timer stand-in tip for a missing tool, matched by keyword in the name.
    static func substitutionTip(for name: String) -> String? {
        let lower = name.lowercased()
        if lower.contains("lid lifter") {
            return "No lid lifter? Tongs plus an oven mitt work."
        }
        if lower.contains("chimney") {
            return "No chimney starter? Light a few briquettes in a metal bucket with vents."
        }
        if lower.contains("trivet") {
            return "No trivet? Three balls of foil under the oven work."
        }
        if lower.contains("glove") {
            return "No heat gloves? Dry leather work gloves or thick oven mitts."
        }
        if lower.contains("parchment") {
            return "No parchment? A light coat of oil works for most recipes."
        }
        return nil
    }
}
