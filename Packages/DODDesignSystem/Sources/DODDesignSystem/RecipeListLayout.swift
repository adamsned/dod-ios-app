import Foundation

/// US-38 / AC-38.1..AC-38.6 / CL-64 (T-650, 2026-05-27) — the layout
/// preference that the Recipes & Articles tab (`FeedView`) and the Search
/// tab (`SearchView`) share via `@AppStorage("dod.recipeListLayout")`.
///
/// Two cases:
///   - ``gallery`` — the existing 2-column `LazyVGrid` per CC-9. Default
///     for new and migrating users (pre-T-650 installs have an absent
///     key, which decodes to `.gallery`).
///   - ``list`` — a denser single-column variant rendered as a
///     `LazyVStack` of ``RecipeCard/ListRow`` rows. Designed for
///     quick-scanning many recipes at a glance.
///
/// **Icon convention (CL-64.1).** The toggle button's `Image(systemName:)`
/// reflects the **current** layout, NOT the destination the user will
/// switch to. This is the opposite of the typical iOS convention; per
/// Spencer's explicit direction, the current-state convention is what
/// ships in v1. The accessibility hint names the destination so VoiceOver
/// users still get the right semantic.
///
/// **Persistence (CL-64.3).** Round-trips through `UserDefaults.standard`
/// under the key ``storageKey`` (`"dod.recipeListLayout"`). The key sits
/// outside the `dod.settings.*` prefix because the layout toggle is an
/// in-tab control, not a Settings-page preference.
///
/// **Hosting (CL-64.3).** The enum lives in `DODDesignSystem` rather than
/// `DODFeatureFeed` so `DODFeatureSearch` can consume it without
/// introducing a cross-feature package dependency.
public enum RecipeListLayout: String, CaseIterable, Sendable {

    /// 2-column `LazyVGrid` per CC-9. Default. Renders `RecipeCard`.
    case gallery

    /// Single-column `LazyVStack` of `RecipeCard.ListRow` rows. Denser
    /// scanning layout introduced by T-650.
    case list

    /// AC-38.2 — the `@AppStorage` key both `FeedView` and `SearchView`
    /// bind to. Outside the `dod.settings.*` prefix because this is an
    /// in-tab control, not a Settings preference.
    public static let storageKey = "dod.recipeListLayout"

    /// AC-38.1 — the SF Symbol shown on the toggle button. Per CL-64.1
    /// the icon reflects the **current** layout, NOT the destination.
    public var toggleIconName: String {
        switch self {
        case .gallery: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }

    /// AC-38.1 — the VoiceOver label spoken when the toggle button gains
    /// focus. Names the **current** state ("Layout, gallery" / "Layout,
    /// list") so VoiceOver users hear what's selected. The destination
    /// is communicated via ``destinationActionHint``.
    public var currentStateAccessibilityLabel: String {
        switch self {
        case .gallery: "Layout, gallery"
        case .list: "Layout, list"
        }
    }

    /// AC-38.1 — the VoiceOver hint spoken after the label. Names the
    /// **destination** ("switch to list" / "switch to gallery") so users
    /// know what tapping will do. Pairs with
    /// ``currentStateAccessibilityLabel`` to give a complete picture
    /// despite the current-state icon convention.
    public var destinationActionHint: String {
        switch self {
        case .gallery: "switch to list"
        case .list: "switch to gallery"
        }
    }

    /// AC-38.2 — flip the layout to the opposite case. Used by the
    /// toggle button's tap handler.
    public mutating func toggle() {
        self = self == .gallery ? .list : .gallery
    }

    /// AC-38.2 / AC-38.6 — defensive read with `.gallery` fallback when
    /// the key is absent or carries an unknown raw value. Marked
    /// `nonisolated` so off-MainActor consumers (and the L1 unit tests)
    /// can call it freely.
    public static func fromDefaults(_ defaults: UserDefaults) -> RecipeListLayout {
        guard let raw = defaults.string(forKey: storageKey),
            let value = RecipeListLayout(rawValue: raw)
        else { return .gallery }
        return value
    }
}
