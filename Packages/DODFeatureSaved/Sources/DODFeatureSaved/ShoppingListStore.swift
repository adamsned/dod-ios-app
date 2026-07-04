import DODSupport
import Foundation

/// Persists the Shopping List across app close/reopen (DUT-488).
///
/// Spec trace: US-39. CL-82 shipped the list as in-memory-only (checked +
/// already-have state "reset on re-init"); DUT-488 makes the list save itself
/// so a force-quit + reopen restores exactly what the cook was looking at.
///
/// **Where it persists (DUT-488):** a single JSON blob in the shared App Group
/// UserDefaults suite (``WidgetSnapshotConfig/appGroupIdentifier``), under
/// ``key``. UserDefaults backed by an App Group suite is the same Apple-
/// recommended path ``WidgetSnapshotStore`` already uses for the widget
/// snapshot — cross-process coordination is handled for us and the payload is
/// tiny. Persisting into the App Group (rather than `.standard`) also leaves the
/// door open for a widget/control to read the list later without a schema move.
///
/// **Never throws (DUT-488):** encode/decode failures are swallowed — a corrupt
/// or unreadable payload is treated as "no saved list" (``load()`` returns nil)
/// rather than crashing the app on launch. This mirrors ``WidgetSnapshotStore``'s
/// `try?`-on-read posture.
///
/// `@unchecked Sendable` is safe for the same reason ``WidgetSnapshotStore`` is:
/// every stored property is a `let`, and `UserDefaults` is documented as
/// thread-safe; the Foundation header just isn't Swift-6-Sendability audited.
public struct ShoppingListStore: @unchecked Sendable {

    /// The persisted snapshot — the three pieces of Shopping List state CL-82
    /// kept in memory (`items` / `checkedIDs` / `alreadyHaveIDs`). `v1` in the
    /// key tags the wire format; a future incompatible shape bumps the key so an
    /// old payload decodes to nil rather than crashing.
    public struct Snapshot: Codable, Sendable, Equatable {
        public var items: [ShoppingListViewModel.Item]
        public var checkedIDs: [UUID]
        public var alreadyHaveIDs: [UUID]

        public init(items: [ShoppingListViewModel.Item], checkedIDs: [UUID], alreadyHaveIDs: [UUID]) {
            self.items = items
            self.checkedIDs = checkedIDs
            self.alreadyHaveIDs = alreadyHaveIDs
        }
    }

    /// UserDefaults key under the App Group suite for the persisted list.
    public static let key = "dod.shoppingList.v1"

    private let defaults: UserDefaults
    private let key: String

    /// Production initializer — joins the shared App Group suite. Returns nil
    /// (like ``WidgetSnapshotStore/init(suiteName:key:)``) if the suite can't be
    /// opened, so callers degrade to an in-memory-only list rather than crash.
    public init?(
        suiteName: String = WidgetSnapshotConfig.appGroupIdentifier,
        key: String = ShoppingListStore.key
    ) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
        self.key = key
    }

    /// Test-only initializer that takes a pre-built `UserDefaults` (e.g. a
    /// per-test `UserDefaults(suiteName:)`) so tests never pollute the App Group
    /// suite or `.standard`. Mirrors ``WidgetSnapshotStore/init(defaults:key:)``.
    public init(defaults: UserDefaults, key: String = ShoppingListStore.key) {
        self.defaults = defaults
        self.key = key
    }

    /// Returns the saved snapshot, or nil when nothing has been saved yet OR the
    /// stored payload can't be decoded (corrupt → treated as "no saved list").
    /// Never throws.
    public func load() -> Snapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    /// Persist the current list state. Fire-and-forget — an encode failure is
    /// swallowed (the in-memory list stays authoritative for the session) and
    /// UserDefaults absorbs any write failure internally.
    public func save(
        items: [ShoppingListViewModel.Item],
        checked: Set<UUID>,
        alreadyHave: Set<UUID>
    ) {
        let snapshot = Snapshot(
            items: items,
            checkedIDs: Array(checked),
            alreadyHaveIDs: Array(alreadyHave)
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    /// DUT-534 — append `rows` to the persisted list in one atomic load →
    /// append → save, preserving the existing checked / already-have sets.
    ///
    /// This is the store-side seam ``LiveShoppingListAppender`` uses to add a
    /// recipe's ingredients from Recipe Detail / a card WITHOUT going through a
    /// ``ShoppingListViewModel`` (those surfaces don't host the list). Reading
    /// the current snapshot first (rather than blindly overwriting) is what
    /// makes an external append additive: it keeps every row the cook already
    /// had, and re-persists the checked / already-have ids untouched so a
    /// half-shopped list isn't reset by an append.
    ///
    /// No-op-safe: an empty `rows` still round-trips the snapshot (harmless);
    /// callers gate on a non-empty build. Never throws — encode/decode failures
    /// are swallowed exactly like ``save(items:checked:alreadyHave:)`` /
    /// ``load()``.
    ///
    /// - Parameter rows: the freshly built per-recipe rows to append (CL-77 —
    ///   appended AS-IS, no cross-row merge, consistent with
    ///   ``ShoppingListViewModel/add(recipes:)``).
    public func append(rows: [ShoppingListViewModel.Item]) {
        let current = load()
        let merged = (current?.items ?? []) + rows
        save(
            items: merged,
            checked: Set(current?.checkedIDs ?? []),
            alreadyHave: Set(current?.alreadyHaveIDs ?? [])
        )
    }

    /// Test helper: drop the persisted list.
    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
