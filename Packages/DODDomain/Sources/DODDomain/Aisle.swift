import Foundation

/// Coarse-grained grocery-store aisle classification for a shopping-list row.
///
/// One of eight buckets — produce, pantry, dairy + eggs, meat + seafood,
/// spices, bakery, frozen, other — used by the Shopping List feature to
/// group ingredients in store-walk order so the cook can shop one section
/// at a time without scanning the entire list.
///
/// **Why an enum and not a free-text string:** the aisle is the only
/// algorithmic decision the Shopping List makes (every other surface is
/// plumbing per CL-67). Pinning the value space to a closed set means the
/// render layer can iterate cases deterministically, the telemetry payload
/// is a coarse ~8-value enum (not raw ingredient text — see AC-39.12), and
/// future tooling that wants to extend coverage (a richer classifier per
/// CL-67's escalation path) gains new cases here rather than mutating the
/// classifier's output shape.
///
/// **Why string raw values:** the persistence layer (T-682) stores
/// `aisleRaw: String` on the SwiftData `ShoppingListItem` model so adding
/// a new case is a `DODDomain` change with zero migration cost (the model
/// reads via `Aisle(rawValue: aisleRaw) ?? .other`). The raw value is also
/// the analytics payload per AC-39.10.
///
/// Spec trace: US-39 / AC-39.4 (aisle grouping render), AC-39.10
/// (telemetry payload), CL-67 (classifier strategy + enum case set).
public enum Aisle: String, Codable, CaseIterable, Sendable, Hashable {
    case produce
    case pantry
    case dairy
    case meat
    case spices
    case bakery
    case frozen
    case other

    /// Human-readable section header. The "+" joins are intentional
    /// (matches the grocery-store-signage idiom; the spec uses the same
    /// convention for "Dairy + Eggs" and "Meat + Seafood").
    public var displayName: String {
        switch self {
        case .produce: return "Produce"
        case .pantry: return "Pantry"
        case .dairy: return "Dairy + Eggs"
        case .meat: return "Meat + Seafood"
        case .spices: return "Spices"
        case .bakery: return "Bakery"
        case .frozen: return "Frozen"
        case .other: return "Other"
        }
    }

    /// Render order for `ShoppingListView`. Sorts staples-first so the
    /// cook walks the store in a sensible path (produce → pantry → dairy →
    /// meat → bakery → frozen → spices → other). The `.other` bucket sits
    /// last because it's the unclassified catch-all per CL-67.
    public var sortIndex: Int {
        switch self {
        case .produce: return 0
        case .pantry: return 1
        case .dairy: return 2
        case .meat: return 3
        case .bakery: return 4
        case .frozen: return 5
        case .spices: return 6
        case .other: return 7
        }
    }
}
