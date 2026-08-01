#if canImport(UIKit)
import UIKit

/// Vends brand image assets from the DesignSystem bundle as `UIImage` for
/// UIKit-side consumers (e.g. the recipe PDF renderer, which draws with
/// `UIGraphicsPDFRenderer` and can't use a SwiftUI `Image`).
///
/// SwiftUI call sites should keep using `Image("dod-logo-badge", bundle:
/// .module)` directly; this exists only for the UIKit drawing paths.
public enum DODBrandAsset {

    /// The circular Dutch Oven Daddy logo badge (`dod-logo-badge`), or `nil` if
    /// the asset can't be resolved.
    public static var logoBadge: UIImage? {
        UIImage(named: "dod-logo-badge", in: .module, compatibleWith: nil)
    }
}
#endif
