import DODDomain
import DODPersistence
import DODSupport
import Foundation

/// DUT-172 — writes the Pinned Collection widget snapshot after collection/saved changes.
public struct PinnedCollectionWidgetPublisher: Sendable {
    public typealias ReloadHook = @Sendable () -> Void

    private let store: RecipeStore
    private let widgetStore: WidgetSnapshotStore?
    private let reload: ReloadHook?

    public init(
        store: RecipeStore,
        widgetStore: WidgetSnapshotStore? = WidgetSnapshotStore(),
        reload: ReloadHook? = nil
    ) {
        self.store = store
        self.widgetStore = widgetStore
        self.reload = reload
    }
}
