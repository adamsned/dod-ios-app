import SwiftUI

/// Typography ramp. Uses system fonts so Dynamic Type works automatically
/// up to AX5 (constitution §7).
///
/// Plan trace: plan.md §5. US-43 / CL-113 (T-710, 2026-05-29) shifted
/// `displayLarge` + `displayMedium` from `.semibold` to `.bold` to match
/// the dutchovendaddy.com section-header weight; ~~`heading` + `caption`
/// adopted SF Rounded for the friendlier card-and-chip register~~ (SF Rounded
/// family swap reverted by CL-128 / T-650, 2026-05-31 — joint @adamsned +
/// @spencer0706 decision); new `brand` token reserved for wordmark moments
/// (Phase c — T-712).
///
/// US-43 amendment / CL-128 (T-650, 2026-05-31) — `heading`, `caption`, and
/// `brand` revert from SF Rounded to the default System font family for
/// visual uniformity across the app. Per joint @adamsned + @spencer0706
/// conversation: brand register comes through weight, color, and spacing
/// instead of via SF Rounded specifically.
public enum DODType {

    /// 34pt+, bold. Top-of-screen titles.
    ///
    /// US-43 / AC-43.6 (T-710, 2026-05-29) — `.semibold` → `.bold`.
    public static let displayLarge: Font = .system(.largeTitle, design: .default, weight: .bold)

    /// 22pt, bold. Section headers.
    ///
    /// US-43 / AC-43.6 (T-710, 2026-05-29) — `.semibold` → `.bold`.
    public static let displayMedium: Font = .system(.title2, design: .default, weight: .bold)

    /// 17pt, semibold. Card titles, prominent labels.
    ///
    /// ~~US-43 / AC-43.7 (T-710, 2026-05-29) — default design → `.rounded`.~~
    /// (reverted to default in CL-128 / T-650, 2026-05-31 — uniform System font.)
    public static let heading: Font = .system(.headline)

    /// 17pt. Default reading text.
    public static let body: Font = .system(.body)

    /// 17pt, semibold. Emphasized body text.
    public static let bodyEmphasized: Font = .system(.body, design: .default, weight: .semibold)

    /// 12pt, medium. Time chips, metadata.
    ///
    /// ~~US-43 / AC-43.7 (T-710, 2026-05-29) — default design + default weight
    /// → `.rounded` + `.medium`.~~ (family swap reverted to default in
    /// CL-128 / T-650, 2026-05-31 — uniform System font; `.medium` weight stands.)
    public static let caption: Font = .system(.caption, weight: .medium)

    /// 22pt, bold. Reserved for "DUTCH OVEN DADDY" wordmark
    /// moments — splash, About, share-sheet preview cards. Reserved-but-unused
    /// in Phase a; Phase c (T-712) is the first consumer when the nav-bar
    /// masthead lands.
    ///
    /// US-43 / AC-43.8 (T-710, 2026-05-29).
    /// (SF Rounded family swap reverted to default in CL-128 / T-650, 2026-05-31 —
    /// uniform System font; size 22 + `.bold` weight stand.)
    public static let brand: Font = .system(size: 22, weight: .bold)
}

extension View {
    /// Convenience: apply a typographic token by name.
    public func dodFont(_ token: Font) -> some View {
        font(token)
    }
}
