import Foundation

/// The curated cast-iron care knowledge base. Doubles as (a) the offline /
/// pre-iOS-27 fallback content and (b) the ground-truth steps the on-device
/// model is told to follow, so a model answer and the fallback read
/// consistently. Covers the five condition states dad's "How to Clean and
/// Restore Cast Iron" article will mirror (DUT-13).
public enum CuratedCastIronCare {

    /// The full curated care guide for a known condition.
    public static func guide(for condition: CastIronCondition) -> CastIronDiagnosis {
        switch condition {
        case .wellSeasoned: return wellSeasoned
        case .sticky: return sticky
        case .lightRust: return lightRust
        case .heavyRust: return heavyRust
        case .cracked: return cracked
        case .neverSeasoned: return neverSeasoned
        case .notCastIron: return generalCare
        }
    }

    /// Neutral "couldn't diagnose - here's general care" guide, used when no
    /// model is available (offline + pre-iOS-27) or the model abstains.
    public static let generalCare = CastIronDiagnosis(
        condition: .notCastIron,
        confidence: 1,
        summary: "Here's the everyday cast iron routine - clean, dry, oil, and re-season when food sticks.",
        steps: [
            CareStep(
                id: 1,
                title: "Clean while warm",
                detail: "Rinse with hot water and a stiff brush while warm. Skip long soaks."
            ),
            CareStep(
                id: 2,
                title: "Dry on heat",
                detail: "Dry fully on the stovetop - never air-dry, which invites rust."
            ),
            CareStep(
                id: 3,
                title: "Oil thin",
                detail: "Wipe a thin coat of neutral oil after each wash; buff until it looks dry."
            ),
            CareStep(
                id: 4,
                title: "Re-season when needed",
                detail: "If food sticks, bake 1-2 thin oil coats at 450-500F for 1 hour."
            ),
        ],
        source: .curated
    )

    // MARK: - Per-condition guides

    static let wellSeasoned = CastIronDiagnosis(
        condition: .wellSeasoned,
        confidence: 1,
        summary: "This pan looks well-seasoned - smooth, even, and dark. Just keep it up.",
        steps: [
            CareStep(
                id: 1,
                title: "Rinse warm",
                detail: "Rinse with hot water and a brush while warm; a quick scrub is fine."
            ),
            CareStep(
                id: 2,
                title: "Dry fully",
                detail: "Towel dry, then set on low heat a minute to drive off the last moisture."
            ),
            CareStep(
                id: 3,
                title: "Oil thin",
                detail: "Buff a very thin coat of neutral oil over the cooking surface."
            ),
        ],
        source: .curated
    )

    static let sticky = CastIronDiagnosis(
        condition: .sticky,
        confidence: 1,
        summary: "The surface feels tacky or gummy - that's excess oil that never fully cured.",
        steps: [
            CareStep(
                id: 1,
                title: "Scrub it back",
                detail: "Scrub with hot water and coarse kosher salt to cut the gummy layer."
            ),
            CareStep(
                id: 2,
                title: "Dry on heat",
                detail: "Rinse, then dry completely on the stovetop."
            ),
            CareStep(
                id: 3,
                title: "Re-bake the layer",
                detail: "Wipe a thin oil coat, bake upside-down at 450F for 1 hour, cool in oven."
            ),
        ],
        source: .curated
    )

    static let lightRust = CastIronDiagnosis(
        condition: .lightRust,
        confidence: 1,
        summary: "Some surface rust, but the iron underneath is fine - this fully recovers.",
        steps: [
            CareStep(
                id: 1,
                title: "Scour the rust",
                detail: "Work the rust off with steel wool or chainmail until you reach gray metal."
            ),
            CareStep(
                id: 2,
                title: "Wash and dry",
                detail: "Wash with hot water and dry immediately and completely on heat."
            ),
            CareStep(
                id: 3,
                title: "Re-season",
                detail: "Bake on 1-2 thin oil coats at 450-500F for 1 hour each."
            ),
        ],
        source: .curated
    )

    static let heavyRust = CastIronDiagnosis(
        condition: .heavyRust,
        confidence: 1,
        summary: "Heavy, flaking rust - salvageable, but it needs a full strip and re-season.",
        steps: [
            CareStep(
                id: 1,
                title: "Strip the rust",
                detail: "Use steel wool, or soak in 1:1 white vinegar and water up to 1 hour - no longer."
            ),
            CareStep(
                id: 2,
                title: "Neutralize and dry",
                detail: "Scrub, rinse well, and dry on heat at once - bare iron flash-rusts fast."
            ),
            CareStep(
                id: 3,
                title: "Re-season 3+ coats",
                detail: "Build 3 or more thin oil coats, baking at 450-500F for 1 hour each."
            ),
        ],
        source: .curated
    )

    static let cracked = CastIronDiagnosis(
        condition: .cracked,
        confidence: 1,
        summary: "There's a crack or deep pit. A cracked pan should be retired from cooking.",
        steps: [
            CareStep(
                id: 1,
                title: "Stop cooking on it",
                detail: "Heat can spread a crack; don't risk it on the stove or in the oven."
            ),
            CareStep(
                id: 2,
                title: "Repurpose it",
                detail: "It can live on as a planter, doorstop, or wall piece - just not for food."
            ),
        ],
        safetyNote: "A cracked pan can fail under heat. Retire it from cooking use.",
        source: .curated
    )

    static let neverSeasoned = CastIronDiagnosis(
        condition: .neverSeasoned,
        confidence: 1,
        summary: "Bare or brand-new iron with no seasoning yet. A few coats and it's ready.",
        steps: [
            CareStep(
                id: 1,
                title: "Wash off the factory coat",
                detail: "Wash with warm soapy water to strip wax or grime, then dry on heat."
            ),
            CareStep(
                id: 2,
                title: "Apply thin coats",
                detail: "Buff an ultra-thin oil coat, then bake upside-down at 450-500F for 1 hour."
            ),
            CareStep(
                id: 3,
                title: "Repeat 3-4 times",
                detail: "Build 3-4 coats for a durable base layer before the first cook."
            ),
        ],
        source: .curated
    )
}
