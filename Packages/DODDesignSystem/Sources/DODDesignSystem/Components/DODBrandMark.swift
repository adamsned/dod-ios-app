import SwiftUI

/// US-43 Phase c (T-712) — the "Dutch Oven Daddy" brand mark, rendered from the
/// existing `App/AppIcon.icon/Assets/DOD Master.png` badge (copied into this
/// module's asset catalog as `dod-masthead`, per AC-43's "reuse the master at
/// ~32pt" call). The circular sawtooth badge already carries the wordmark, so
/// the masthead needs no separate `DODType.brand` wordmark text beside it.
///
/// Decorative by default — the accompanying screen title carries the semantic
/// label — so it's hidden from accessibility unless a host opts in.
public struct DODBrandMark: View {

    private let size: CGFloat

    /// - Parameter size: the mark's rendered edge length. Defaults to the AC-43
    ///   masthead size (~32pt).
    public init(size: CGFloat = 32) {
        self.size = size
    }

    public var body: some View {
        Image("dod-masthead", bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview("Brand mark") {
    HStack(spacing: DODSpacing.sm) {
        DODBrandMark()
        DODBrandMark(size: 48)
    }
    .padding(DODSpacing.md)
    .background(DODColor.surface)
}
