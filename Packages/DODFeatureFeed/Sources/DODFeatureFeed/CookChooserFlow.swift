import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-194 — the unified "What are we cooking?" chooser. The First Cookout entry
/// (the hero "Let's cook" + the toolbar flame) lands here so choosing your cook
/// is easy and front-and-center, instead of the flow jumping straight into one
/// fixed dish. Mirrors ``DumpCakeFlow``'s proven picker-then-flow shape: one
/// sheet, a `List` that swaps in place to the full paged ``FirstCookoutView``
/// once a row is picked. Rungs and dump cakes already terminate in the same
/// flow, so one `GuidedCookout?` selection unifies them. Reads
/// ``GuidedCookout/path`` dynamically, so the campfire rung appears for free
/// once that lands.
struct CookChooserFlow: View {

    /// The progress-aware default (FeedView's `currentRung`), hoisted + badged.
    let recommended: GuidedCookout?
    let onLogCook: (CookLogEntry) -> Void

    @State private var selected: GuidedCookout?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let selected {
            FirstCookoutView(cookout: selected, onLogCook: onLogCook)
        } else {
            // DUT-235 — always show the chooser as the first screen so the cook
            // picks their first cook (no auto-jump into the lasagna). The
            // recommended rung is hoisted + badged at the top, so a beginner still
            // has an obvious one-tap target — they just get to see the choice.
            picker
        }
    }

    /// The recommended rung hoisted to the front of ``GuidedCookout/path``,
    /// de-duped by `recipeID`. Pure for testability.
    nonisolated static func orderedRungs(recommended: GuidedCookout?) -> [GuidedCookout] {
        var seen = Set<Int>()
        var ordered: [GuidedCookout] = []
        for rung in [recommended].compactMap({ $0 }) + GuidedCookout.path
        where seen.insert(rung.recipeID).inserted {
            ordered.append(rung)
        }
        return ordered
    }

    private var orderedRungs: [GuidedCookout] {
        Self.orderedRungs(recommended: recommended)
    }

    private var picker: some View {
        NavigationStack {
            List {
                pathSection
                dumpCakeSection
            }
            .scrollContentBackground(.hidden)
            .background(DODColor.surface)
            .navigationTitle("What are we cooking?")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(DODColor.burntOrange)
                }
            }
        }
    }

    @ViewBuilder private var pathSection: some View {
        Section("Your Path") {
            ForEach(orderedRungs, id: \.recipeID) { rung in
                Button {
                    selected = rung
                } label: {
                    HStack(spacing: DODSpacing.sm) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(DODColor.burntOrange)
                        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                            Text(rung.dishTitle)
                                .dodFont(DODType.body)
                                .foregroundStyle(DODColor.label)
                            if rung.recipeID == recommended?.recipeID {
                                Text(rung.isFirstRung ? "START HERE" : "YOUR NEXT WIN")
                                    .dodFont(DODType.caption)
                                    .foregroundStyle(DODColor.burntOrange)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DODColor.labelSecondary)
                    }
                }
                .listRowBackground(DODColor.surfaceElevated)
                .accessibilityIdentifier("cook-chooser-rung-\(rung.recipeID)")
            }
        }
    }

    @ViewBuilder private var dumpCakeSection: some View {
        Section("Dump Cakes") {
            ForEach(DumpCake.all) { cake in
                Button {
                    selected = .dumpCake(cake)
                } label: {
                    HStack(spacing: DODSpacing.sm) {
                        Image(systemName: "birthday.cake.fill")
                            .foregroundStyle(DODColor.burntOrange)
                        Text(cake.title)
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.label)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DODColor.labelSecondary)
                    }
                }
                .listRowBackground(DODColor.surfaceElevated)
                .accessibilityIdentifier("cook-chooser-dump-\(cake.id)")
            }
        }
    }
}
