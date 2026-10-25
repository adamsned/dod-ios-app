import DODDomain
import Foundation

/// In-memory cache of model parses keyed by `RecipeIngredient.id` (DUT-1020).
/// `RecipeIngredient.id` is deterministic from text (+ index), so it is stable
/// across re-parses. A cached `nil` means "model declined" and is not retried.
public actor IngredientParseCache {
    private var storage: [UUID: IngredientParse?] = [:]

    public init() {}

    public func cached(for id: UUID) -> IngredientParse?? { storage[id] }

    public func store(_ parse: IngredientParse?, for id: UUID) { storage[id] = .some(parse) }

    public func removeAll() { storage.removeAll() }
}
