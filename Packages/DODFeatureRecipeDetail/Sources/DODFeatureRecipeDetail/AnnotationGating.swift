import Foundation

/// Pure gating decision for the instructions-annotation affordance (iPad +
/// Apple Pencil, v2).
///
/// The handwritten-annotation feature is **iPad-only**: on iPhone (and any
/// compact-width layout — e.g. an iPad Slide Over / narrow split) NONE of it
/// renders, keeping the iPhone reading view byte-identical. This helper takes
/// plain `Bool`s (not SwiftUI / UIKit types) so the "iPhone-hidden / iPad-shown"
/// contract is unit-testable on the macOS `swift test` slice, with no view
/// hosting and no `#if os(iOS)` at the call site of the test.
///
/// The call site (iOS-guarded) computes:
/// - `isRegularWidth` from `horizontalSizeClass == .regular`
/// - `isPad` from `UIDevice.current.userInterfaceIdiom == .pad`
///
/// Both are required: idiom alone would show the affordance in a compact iPad
/// multitasking pane (where the reading column is iPhone-narrow), and size
/// class alone could theoretically match a future large non-pad surface.
public func shouldShowAnnotateAffordance(isRegularWidth: Bool, isPad: Bool) -> Bool {
    isRegularWidth && isPad
}
