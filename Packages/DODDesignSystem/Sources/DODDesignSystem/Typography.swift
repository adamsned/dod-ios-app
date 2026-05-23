import SwiftUI

/// Typography ramp. Uses system fonts so Dynamic Type works automatically
/// up to AX5 (constitution §7).
///
/// Plan trace: plan.md §5.
public enum DODType {

    /// 34pt+, semibold. Top-of-screen titles.
    public static let displayLarge: Font = .system(.largeTitle, design: .default, weight: .semibold)

    /// 22pt, semibold. Section headers.
    public static let displayMedium: Font = .system(.title2, design: .default, weight: .semibold)

    /// 17pt, semibold. Card titles, prominent labels.
    public static let heading: Font = .system(.headline)

    /// 17pt. Default reading text.
    public static let body: Font = .system(.body)

    /// 17pt, semibold. Emphasized body text.
    public static let bodyEmphasized: Font = .system(.body, design: .default, weight: .semibold)

    /// 12pt. Time chips, metadata.
    public static let caption: Font = .system(.caption)
}

extension View {
    /// Convenience: apply a typographic token by name.
    public func dodFont(_ token: Font) -> some View {
        font(token)
    }
}
