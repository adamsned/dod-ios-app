import SwiftUI

/// Shimmer placeholder. Animates a soft gradient sweep across a rounded
/// rectangle; falls back to a static fill when Reduce Motion is enabled
/// (constitution §7).
///
/// Spec trace: spec.md CC-3 (loading states).
public struct LoadingSkeleton: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = DODRadius.inner) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(baseFill)
            .overlay(shimmerOverlay)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }

    private var baseFill: Color {
        DODColor.labelSecondary.opacity(0.18)
    }

    @ViewBuilder
    private var shimmerOverlay: some View {
        if reduceMotion {
            EmptyView()
        } else {
            GeometryReader { proxy in
                let stripeWidth = proxy.size.width * 0.5
                LinearGradient(
                    // DUT-252: appearance-stable light highlight. `surfaceElevated` is
                    // DARKER than the base in Dark Mode, which inverts/erases the shimmer.
                    colors: [.clear, Color.white.opacity(0.35), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: stripeWidth)
                .offset(x: phase * proxy.size.width)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
    }
}

#Preview("Skeleton row") {
    VStack(spacing: DODSpacing.sm) {
        LoadingSkeleton().frame(height: 120)
        LoadingSkeleton().frame(height: 16).padding(.horizontal, DODSpacing.lg)
        LoadingSkeleton().frame(height: 16).padding(.horizontal, DODSpacing.xl)
    }
    .padding(DODSpacing.md)
}
