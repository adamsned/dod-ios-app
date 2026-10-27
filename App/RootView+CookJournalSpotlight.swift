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

    /// Index `entries` and drop stale items. Returns the new identifier set (the caller's next baseline).
    /// - Parameter purgeDomainFirst: true on the first run of a launch, to clear cross-launch stragglers.
    static func sync(
        entries: [CookLogEntry],
        previous: Set<String>,
        purgeDomainFirst: Bool,
        photoBytes: @escaping @Sendable (String) -> Data?,
        index: CSSearchableIndex = .default()
    ) async throws -> Set<String> {
        if purgeDomainFirst {
            try await index.deleteSearchableItems(withDomainIdentifiers: [CookJournalSpotlightIndexer.domainIdentifier])
        }
        let indexer = CookJournalSpotlightIndexer(
            photoBytes: photoBytes,
            indexBatch: { batch in try await index.indexSearchableItems(batch) }
        )
        try await indexer.index(entries: entries)
        if !purgeDomainFirst {
            let stale = staleIdentifiers(previous: previous, entries: entries)
            if !stale.isEmpty { try await index.deleteSearchableItems(withIdentifiers: stale) }
        }
        return Set(entries.map { CookJournalSpotlightIndexer.identifier(for: $0.id) })
    }

    /// Live entry point: read all logs from the registered store and sync.
    static func syncFromStore(previous: Set<String>, purgeDomainFirst: Bool) async -> Set<String>? {
        let entries = await CookJournalEntryEntityQuery.allEntries()
        let photos = CookPhotoStore()
        do {
            return try await sync(
                entries: entries,
                previous: previous,
                purgeDomainFirst: purgeDomainFirst,
                photoBytes: { photos.data(forID: $0) }
            )
        } catch {
            DODLog.app.error("cook journal spotlight index failed: \(String(describing: error))")
            return nil
        }
    }
}
