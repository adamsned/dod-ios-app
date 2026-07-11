import Foundation

/// DUT-648: the Shopping List append de-dup. Split out of
/// `ShoppingListViewModel.swift` so that file stays under SwiftLint's
/// `file_length` (400-line) cap — same split pattern used across the codebase.
extension ShoppingListViewModel {

    /// Append `adding` to `existing`, skipping any new row that duplicates one
    /// already present (DUT-589 / DUT-648). Shared by ``add(recipes:)`` and
    /// ``ShoppingListStore/append(rows:)``.
    ///
    /// The de-dup identity is `(recipeTitle, ingredientText, occurrence)`,
    /// `occurrence` being the ordinal of the line among identical
    /// `(recipeTitle, ingredientText)` lines WITHIN ITS OWN batch. A recipe that
    /// legitimately repeats a line gets occurrences 0 and 1, so BOTH survive (the
    /// old pair-only key dropped the second → under-buy); a whole-recipe re-add
    /// reproduces the same occurrence sequence, so every line collides and the
    /// recipe is skipped (no re-stacking). Batch-scoping the occurrence is what
    /// tells those two cases apart, and it matches what `init(recipes:)` produces
    /// implicitly — so build and append now follow ONE rule.
    nonisolated static func dedupedAppend(existing: [Item], adding: [Item]) -> [Item] {
        existing + newRows(existing: existing, adding: adding)
    }

    /// The subset of `adding` that survives the de-dup check against
    /// `existing` (see ``dedupedAppend(existing:adding:)``), WITHOUT the
    /// `existing` prefix. Exposed so a caller can run the de-dup CHECK against
    /// a narrower/filtered view of its existing rows while still merging the
    /// result onto its full, unfiltered list — see
    /// ``ShoppingListStore/append(rows:)``, which checks against a
    /// legacy-masked-row-excluded view so an invisible masked row can't
    /// silently swallow a genuine re-add, while leaving that masked row (and
    /// every other existing row) untouched in what it persists.
    nonisolated static func newRows(existing: [Item], adding: [Item]) -> [Item] {
        let existingKeys = Set(occurrenceKeys(for: existing))
        var result: [Item] = []
        for (row, key) in zip(adding, occurrenceKeys(for: adding)) where !existingKeys.contains(key) {
            result.append(row)
        }
        return result
    }

    /// The per-batch occurrence key for each row, in order: the Nth identical
    /// `(recipeTitle, ingredientText)` line in the batch gets `occurrence == N`.
    private nonisolated static func occurrenceKeys(for rows: [Item]) -> [RowKey] {
        var counts: [RowKey: Int] = [:]
        return rows.map { row in
            let pair = RowKey(recipeTitle: row.recipeTitle, text: row.ingredientText, occurrence: 0)
            let occurrence = counts[pair, default: 0]
            counts[pair, default: 0] += 1
            return RowKey(recipeTitle: row.recipeTitle, text: row.ingredientText, occurrence: occurrence)
        }
    }

    /// De-dup identity: source recipe + ingredient line + the ordinal of that
    /// line among identical lines from the same recipe (DUT-648).
    private struct RowKey: Hashable {
        let recipeTitle: String
        let text: String
        let occurrence: Int
    }
}
