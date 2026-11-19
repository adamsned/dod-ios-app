import DODDesignSystem
import DODDomain
import SwiftUI

/// DUT-985 — one-time expectation setter shown before Cook Mode on the user's first cook.
struct CookPepTalkView: View {
    let recipe: Recipe
    let onStart: () -> Void
    let onCancel: () -> Void

    /// 'About 45 min' from totalTime, else cookTime, else nil.
    nonisolated static func timeCommitmentText(for recipe: Recipe) -> String? {
        guard let duration = recipe.totalTime ?? recipe.cookTime else { return nil }
        let minutes = Int(exactly: (Double(duration.components.seconds) / 60).rounded()) ?? 0
        guard minutes > 0 else { return nil }
        if minutes < 60 { return "About \(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "About \(hours) hr" : "About \(hours) hr \(remainder) min"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Here's what to expect").font(.title.bold())
                if let time = Self.timeCommitmentText(for: recipe) {
                    Label(time, systemImage: "clock")
                }
                Text("Mistakes are normal on a first cook. Take it one step at a time — you can pause anytime.")
                if let url = recipe.heroImageLargeURL ?? recipe.heroImage {
                    AsyncImage(url: url) {
                        $0.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Finished \(recipe.title)")
                }
                Text("Done looks like this.").font(.headline)
                Button("Start cooking", action: onStart).buttonStyle(.borderedProminent)
                Button("Not now", action: onCancel)
            }
            .padding()
        }
        .background(DODColor.surface.ignoresSafeArea())
    }
}
