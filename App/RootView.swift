import DODAnalytics
import DODDesignSystem
// Linkage proof for T-006. Each module exposes a placeholder namespace enum;
// the real composition root lands in T-140.
import DODDomain
import DODFeatureCategories
import DODFeatureFeed
import DODFeatureRecipeDetail
import DODFeatureSaved
import DODFeatureSearch
import DODNetworking
import DODPersistence
import DODSupport
import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Dutch Oven Daddy")
                .font(.largeTitle)
            Text("Scaffolding complete — Cluster A.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    RootView()
}
