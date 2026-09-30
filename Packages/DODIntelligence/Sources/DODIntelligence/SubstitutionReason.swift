import Foundation

/// Why the cook wants to swap an ingredient. Picked in the Shopping List's
/// substitution sheet BEFORE the on-device model runs, and passed to
/// ``DODIntelligenceService/suggestSubstitution(for:reason:)`` so the suggestion
/// fits the need — a dairy-free swap reads very differently from a lower-carb
/// one. `nil` at the call site means "no specific reason": a general pantry swap.
public enum SubstitutionReason: String, CaseIterable, Sendable, Identifiable {
    /// The cook simply doesn't have it on hand.
    case outOfIt
    /// A true allergy — the substitute must avoid the ingredient entirely.
    case allergy
    /// An intolerance or sensitivity (e.g. lactose).
    case sensitivity
    /// A lower-carbohydrate alternative.
    case lowerCarb
    /// A dairy-free alternative.
    case dairyFree
    /// A gluten-free alternative.
    case glutenFree

    public var id: String { rawValue }

    /// A true allergy — the strongest safety framing. Drives the extra-prominent
    /// warning and the stronger haptic cue on the result (req: allergy gets
    /// substantially more emphasis than an ordinary swap reason).
    public var isAllergy: Bool { self == .allergy }

    /// An allergy OR an intolerance/sensitivity — the reasons that surface the
    /// expanded allergen disclaimer (verify the actual ingredient + allergen
    /// info yourself), since an AI swap must never be trusted as medical-grade
    /// for these.
    public var requiresAllergenWarning: Bool {
        self == .allergy || self == .sensitivity
    }

    /// Title Case chip label for the picker (controls → Title Case, CL-305).
    public var title: String {
        switch self {
        case .outOfIt: return "Out of It"
        case .allergy: return "Allergy"
        case .sensitivity: return "Sensitivity"
        case .lowerCarb: return "Lower Carb"
        case .dairyFree: return "Dairy-Free"
        case .glutenFree: return "Gluten-Free"
        }
    }

    /// The clause folded into the model prompt so the suggestion matches the
    /// reason. Written as a sentence fragment completing "because ...".
    public var promptClause: String {
        switch self {
        case .outOfIt: return "the cook is out of it and wants a common pantry swap"
        case .allergy: return "the cook is allergic to it, so the substitute must avoid it entirely"
        case .sensitivity: return "the cook has a sensitivity or intolerance to it"
        case .lowerCarb: return "the cook wants a lower-carbohydrate alternative"
        case .dairyFree: return "the cook needs a dairy-free alternative"
        case .glutenFree: return "the cook needs a gluten-free alternative"
        }
    }
}
