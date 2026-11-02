import CoreSpotlight
import DODSupport
import Foundation

/// DUT-1018 — indexes the user's cook-journal entries into Spotlight, separate from the recipe domain.
struct CookJournalSpotlightIndexer {
    static let domainIdentifier = "com.dutchovendaddy.DODApp.cookjournal"
    static func identifier(for id: UUID) -> String { "dod.cookjournal.\(id.uuidString)" }

    let batchSize: Int
    let thumbnailMaxPixel: Int
    /// Photo bytes for an entry's `photoLocalID`, or nil.
    let photoBytes: @Sendable (String) -> Data?
    let downsample: @Sendable (Data, Int) -> Data?
    let indexBatch: @Sendable ([CSSearchableItem]) async throws -> Void

    init(
        batchSize: Int = 12,
        thumbnailMaxPixel: Int = 300,
        photoBytes: @escaping @Sendable (String) -> Data?,
        downsample: @escaping @Sendable (Data, Int) -> Data? = SpotlightIndexer.imageIODownsample,
        indexBatch: @escaping @Sendable ([CSSearchableItem]) async throws -> Void
    ) {
        self.batchSize = batchSize
        self.thumbnailMaxPixel = thumbnailMaxPixel
        self.photoBytes = photoBytes
        self.downsample = downsample
        self.indexBatch = indexBatch
    }

    func index(entries: [CookLogEntry]) async throws {
        var batch: [CSSearchableItem] = []
        for entry in entries {
            let entity = CookJournalEntryEntity(entry: entry)
            let set = entity.attributeSet
            if let photoID = entry.photoLocalID, let raw = photoBytes(photoID) {
                set.thumbnailData = downsample(raw, thumbnailMaxPixel)
            }
            let item = CSSearchableItem(
                uniqueIdentifier: Self.identifier(for: entry.id),
                domainIdentifier: Self.domainIdentifier,
                attributeSet: set
            )
            if #available(iOS 18, *) {
                item.associateAppEntity(entity, priority: 1)
            }
            batch.append(item)
            if batch.count >= batchSize {
                try await indexBatch(batch)
                batch.removeAll(keepingCapacity: true)
            }
        }
        if !batch.isEmpty { try await indexBatch(batch) }
    }
}
