import CoreSpotlight
import DODAnalytics
import DODSupport
import SwiftUI

extension RootView {

    /// (Re)index the suggested recipes into Spotlight (US-10 / DUT-12). Extracted
    /// here so `RootView` stays under the SwiftLint file_length / type_body_length
    /// caps.
    func indexSpotlight() async {
        // DUT-361: serialize — a foreground bounce can fire a second reindex while
        // the first is still awaiting; running them concurrently can interleave the
        // domain delete + index. One at a time keeps delete+index atomic per run.
        guard !isIndexingSpotlight else { return }
        isIndexingSpotlight = true
        defer { isIndexingSpotlight = false }
        do {
            let payloads = try await RecipeEntityQuery.suggestedPayloads()
            let items = payloads.map { payload -> CSSearchableItem in
                let entity = RecipeEntity(payload: payload)
                return CSSearchableItem(
                    uniqueIdentifier: "dod.recipe.\(payload.id)",
                    domainIdentifier: "com.dutchovendaddy.DODApp.recipes",
                    attributeSet: entity.attributeSet
                )
            }
            // DUT-308: drop the whole recipe domain before each (re)index so an
            // unsaved/cleared recipe doesn't linger in Spotlight (was upsert-only).
            let index = CSSearchableIndex.default()
            try await index.deleteSearchableItems(withDomainIdentifiers: [
                "com.dutchovendaddy.DODApp.recipes"
            ])
            try await index.indexSearchableItems(items)
        } catch {
            DODLog.app.error("spotlight index failed: \(String(describing: error))")
        }
    }
}
