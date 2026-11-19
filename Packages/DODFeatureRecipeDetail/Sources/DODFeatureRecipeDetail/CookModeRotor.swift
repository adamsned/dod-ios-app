import SwiftUI

/// DUT-116 — the landmarks exposed on the "Cook Mode" VoiceOver rotor.
enum CookModeRotorItem: String, CaseIterable, Equatable {
    case currentStep, nextStep, stepIngredients, activeTimer, exit

    var title: String {
        switch self {
        case .currentStep: "Current step"
        case .nextStep: "Next step"
        case .stepIngredients: "Ingredients for this step"
        case .activeTimer: "Active timer"
        case .exit: "Back to recipe"
        }
    }

    /// Items that make sense right now, in rotor order. `currentStep` and `exit`
    /// are always present.
    static func available(hasNextStep: Bool, hasActiveTimer: Bool, hasStepIngredients: Bool) -> [CookModeRotorItem] {
        allCases.filter {
            switch $0 {
            case .nextStep: hasNextStep
            case .activeTimer: hasActiveTimer
            case .stepIngredients: hasStepIngredients
            case .currentStep, .exit: true
            }
        }
    }
}

extension View {
    /// Adds the "Cook Mode" rotor. `perform` is called when the user lands on an
    /// entry; the caller announces content / closes Cook Mode there.
    func cookModeRotor(
        items: [CookModeRotorItem],
        perform: @escaping (CookModeRotorItem) -> Void
    ) -> some View {
        modifier(CookModeRotorModifier(items: items, perform: perform))
    }
}

private struct CookModeRotorModifier: ViewModifier {
    let items: [CookModeRotorItem]
    let perform: (CookModeRotorItem) -> Void
    @Namespace private var rotorSpace

    func body(content: Content) -> some View {
        content
            .accessibilityRotor("Cook Mode") {
                ForEach(items, id: \.self) { item in
                    AccessibilityRotorEntry(Text(item.title), id: item.rawValue, in: rotorSpace) {
                        perform(item)
                    }
                }
            }
    }
}
