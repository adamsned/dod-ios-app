import DODDesignSystem
import SwiftUI

/// DUT-170 — inline WPRM step photo on a Cook Mode step card.
struct CookModeStepImage: View {
    let url: URL?
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isExpanded = false

    /// Pure + testable: shorter image at accessibility sizes so text keeps room.
    static func maxHeight(for size: DynamicTypeSize) -> CGFloat {
        size.isAccessibilitySize ? 120 : 220
    }

    var body: some View {
        if let url {
            ReliableImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    Button {
                        isExpanded = true
                    } label: {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: Self.maxHeight(for: typeSize))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Step photo. Double tap to expand.")
                    .accessibilityIdentifier("cook-mode-step-image")
                    #if os(iOS)
                    .fullScreenCover(isPresented: $isExpanded) {
                        ZStack(alignment: .topTrailing) {
                            Color.black.ignoresSafeArea()
                            image.resizable().scaledToFit()
                            Button("Close") { isExpanded = false }
                            .padding().foregroundStyle(.white)
                        }
                    }
                    #else
                    .sheet(isPresented: $isExpanded) {
                        ZStack(alignment: .topTrailing) {
                            Color.black.ignoresSafeArea()
                            image.resizable().scaledToFit()
                            Button("Close") { isExpanded = false }
                            .padding().foregroundStyle(.white)
                        }
                    }
                    #endif
                case .empty:
                    ProgressView().frame(height: 80).frame(maxWidth: .infinity)
                case .failure:
                    EmptyView()
                }
            }
        }
    }
}
