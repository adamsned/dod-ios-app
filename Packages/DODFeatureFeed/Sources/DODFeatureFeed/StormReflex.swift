import DODSupport
import Foundation

/// DUT-998 companion — mid-cook "conditions changed" nudge. Manual because live weather is usually unavailable off-grid.
enum StormReflex {
    enum Change: Equatable {
        case windKickedUp
        case windDied
        case gotCold
        case gotHot
        case backToMild
    }

    /// Returns a one-line nudge, or nil when the change does not move the coal count.
    static func nudge(for change: Change, model: HeatCoachModel) -> String? {
        let newAmbient: AmbientCondition
        let newWindy: Bool
        switch change {
        case .windKickedUp: (newAmbient, newWindy) = (model.ambient, true)
        case .windDied: (newAmbient, newWindy) = (model.ambient, false)
        case .gotCold: (newAmbient, newWindy) = (.cold, model.windy)
        case .gotHot: (newAmbient, newWindy) = (.hot, model.windy)
        case .backToMild: (newAmbient, newWindy) = (.mild, model.windy)
        }
        let diff = model.coalTotalChange(newAmbient: newAmbient, newWindy: newWindy)
        guard diff != 0 else { return nil }
        let count = abs(diff)
        let word = count == 1 ? "coal" : "coals"
        return diff > 0
            ? "Conditions changed: add \(count) \(word) to hold your heat."
            : "Conditions changed: pull \(count) \(word) to avoid overheating."
    }
}
