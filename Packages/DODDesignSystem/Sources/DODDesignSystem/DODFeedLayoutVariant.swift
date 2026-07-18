import Foundation

/// US-43 Phase b/c/d (T-711..T-713) — the compositional-refresh flag that gates
/// the "magazine" register (16:9 heroes, editorial cards, the nav masthead, and
/// the numbered "Popular" badge) behind a reversible per-install switch.
///
/// Distinct from ``RecipeListLayout`` (which chooses *grid vs. list*); this axis
/// chooses *classic vs. magazine styling* and composes with either grid or list.
/// Both are Feed/Search-shared and live in `DODDesignSystem` so the components
/// (`RecipeCard`) AND the feature modules can read the same value without a
/// cross-feature package edge (mirrors ``RecipeListLayout``'s hosting rationale).
///
/// **Default (first cut).** New / migrating installs (absent key) resolve to
/// ``LayoutVariant/magazine`` so the refreshed look is what ships and
/// screenshots. Per US-43's "behind-the-flag from Phase b on" note, a user can
/// flip back to ``LayoutVariant/classic`` from Settings ▸ Customization and the
/// pre-refresh look returns byte-for-byte (the components default to `.classic`,
/// so every non-Feed host stays byte-identical regardless of this key).
public enum DODFeed {

    /// The compositional variant applied to the Recipes & Articles feed.
    public enum LayoutVariant: String, CaseIterable, Sendable {

        /// The pre-US-43-Phase-b card + header treatment (portrait-ish 140pt
        /// hero, `.headline` title, plain screen header). Reverting to this
        /// restores the classic look on every gated surface.
        case classic

        /// The magazine register: 16:9 landscape heroes, bolder display-weight
        /// titles leaning on the `SurfaceElevated` borderless-on-light collapse,
        /// the brand-mark masthead, and the numbered "Popular" badge.
        case magazine

        /// Human-readable name for the Settings ▸ Customization picker.
        public var displayName: String {
            switch self {
            case .classic: "Classic"
            case .magazine: "Magazine"
            }
        }
    }

    /// The `@AppStorage` / `UserDefaults` key both `FeedView` and the Settings
    /// picker bind to. Outside the `dod.settings.*` prefix (like
    /// ``RecipeListLayout/storageKey``) because it drives an in-tab visual
    /// register, not a discrete Settings preference value.
    public static let layoutVariantStorageKey = "dod.feed.layoutVariant"

    /// Defensive read with a ``LayoutVariant/magazine`` fallback when the key is
    /// absent or carries an unknown raw value (first cut defaults ON). Marked
    /// `nonisolated`-friendly (a plain static) so off-`MainActor` callers and the
    /// L1 unit tests can resolve the variant freely.
    public static func layoutVariant(from defaults: UserDefaults) -> LayoutVariant {
        guard let raw = defaults.string(forKey: layoutVariantStorageKey),
            let value = LayoutVariant(rawValue: raw)
        else { return .magazine }
        return value
    }
}
