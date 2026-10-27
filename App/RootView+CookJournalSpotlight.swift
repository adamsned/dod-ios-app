import CoreSpotlight
import DODPersistence
import DODSupport
import Foundation

/// DUT-1018 — keeps the cook-journal Spotlight domain in step with `CookLogEntry` rows.
enum CookJournalSpotlightSync {
    /// Identifiers to delete: previously indexed ones no longer present.
    static func staleIdentifiers(previous: Set<String>, entries: [CookLogEntry]) -> [String] {
        let current = Set(entries.map { CookJournalSpotlightIndexer.identifier(for: $0.id) })
        return Array(previous.subtracting(current))
    }
}
