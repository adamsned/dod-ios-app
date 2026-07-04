import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-194 / CL-265 — the "Your First Cookout" guided-path chooser. Redesigned
/// from a plain grouped `List` into a vertical **roadmap**: a large title +
/// subheader that frame the learning journey, the curated rungs rendered as a
/// connected path of tappable dish cards (each node showing the cook's progress
/// — done / current / upcoming, derived from the recommended rung), and the
/// off-path dump cakes as an "Anytime Treats" section. Picking any card swaps
/// this screen in place for the full paged ``FirstCookoutView`` (mirrors
/// ``DumpCakeFlow``). Reads ``GuidedCookout/path`` dynamically, so new rungs
/// appear on the path for free.
struct CookChooserFlow: View {

    /// The progress-aware default (FeedView's `currentRung`) — the cook's
    /// current spot on the path. `nil` once every rung is cooked (a graduate).
    let recommended: GuidedCookout?
    /// DUT-381 — recipe ids the cook has actually logged, so a rung they cooked
    /// out of order still renders as done (the roadmap is freely tappable).
    var cookedRecipeIDs: Set<Int> = []
    let onLogCook: (CookLogEntry) -> Void

    @State private var selected: GuidedCookout?
    /// DUT-484: the guided path OWNS the bake-timer engine so a running
    /// countdown survives a "Back to the path" → re-enter cycle (which tears the
    /// `FirstCookoutView` down and rebuilds it). Without this the rebuilt view
    /// lost the timer and, on restart, re-scheduled the bake-done alert to a
    /// wrong full-length deadline.
    @State private var timerEngine = CookTimerEngine()
    /// DUT-548: the guided path OWNS the "already logged" set (keyed by rung
    /// recipeID, matching DUT-547) so a first cook already logged on a rung isn't
    /// logged a SECOND time after "Back to the path" → re-enter (which rebuilds
    /// `FirstCookoutView` with a fresh per-view `hasLoggedCook`). Without this the
    /// only backstop was the persistence ±3s dedup, which a minutes-apart
    /// re-enter sails past → an inflated cook count + a false rank-up.
    @State private var loggedRecipeIDs: Set<Int> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let selected {
            // CL-267 — `onBack` returns to the roadmap (clears the selection) so a
            // picked recipe isn't a dead end; the X still closes the whole sheet.
            FirstCookoutView(
                cookout: selected,
                onLogCook: onLogCook,
                onBack: { self.selected = nil },
                timerEngine: timerEngine,
                loggedRecipeIDs: $loggedRecipeIDs  // DUT-548 — dedup across re-enter.
            )
        } else {
            // DUT-235 — always show the chooser first (no auto-jump into a dish);
            // the recommended rung is highlighted in place as the "start here".
            picker
        }
    }

    private var picker: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.lg) {
                    header
                    pathSection
                    dumpCakeSection
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.top, DODSpacing.sm)
                .padding(.bottom, DODSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(DODColor.surface)
            .navigationTitle("")
            .dodInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(DODColor.burntOrange)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("Your First Cookout")
                .dodFont(DODType.displayLarge)
                .foregroundStyle(DODColor.labelStrong)
            Text(
                "New to Dutch oven cooking? Start here. Each stop on the path is one "
                    + "guaranteed win, building real skills and confidence, from your first "
                    + "cook at home to the campfire everyone remembers."
            )
            .dodFont(DODType.detail)
            .foregroundStyle(DODColor.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("cook-chooser-subheader")
        }
    }

    // MARK: - The path

    private var pathRungs: [GuidedCookout] { GuidedCookout.path }

    private func nodeState(_ index: Int) -> CookPathNode.NodeState {
        Self.nodeState(
            index: index,
            recommended: recommended,
            cookedRecipeIDs: cookedRecipeIDs,
            path: pathRungs
        )
    }

    /// Pure, testable position → state mapping: rungs before the cook's
    /// recommended (current) rung are done, the recommended is current, and the
    /// rest are upcoming. A `nil` recommended (a path graduate, everything
    /// cooked) makes every rung done.
    nonisolated static func nodeState(
        index: Int,
        recommended: GuidedCookout?,
        cookedRecipeIDs: Set<Int> = [],
        path: [GuidedCookout] = GuidedCookout.path
    ) -> CookPathNode.NodeState {
        // DUT-381: a rung the user ACTUALLY cooked is done regardless of its
        // position — the roadmap is freely tappable, so completion isn't strictly
        // in-order (e.g. cooking rung 2 before rung 1). Falls through to the
        // recommended-position mapping when this rung isn't (yet) cooked, which
        // preserves the original behavior when no cook history is supplied.
        if index >= 0, index < path.count, cookedRecipeIDs.contains(path[index].recipeID) {
            return .done
        }
        guard let recommended,
            let current = path.firstIndex(where: { $0.recipeID == recommended.recipeID })
        else { return .done }
        if index < current { return .done }
        if index == current { return .current }
        return .upcoming
    }

    @ViewBuilder private var pathSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(pathRungs.enumerated()), id: \.element.recipeID) { index, rung in
                CookPathNode(
                    rung: rung,
                    number: index + 1,
                    state: nodeState(index),
                    isLast: index == pathRungs.count - 1
                ) {
                    selected = rung
                }
            }
        }
    }

    // MARK: - Off-path treats

    @ViewBuilder private var dumpCakeSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text("Anytime Treats")
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.labelStrong)
                Text("Sweet, foolproof dump cakes. Off the path, ready whenever you want an easy win.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(DumpCake.all) { cake in
                Button {
                    selected = .dumpCake(cake)
                } label: {
                    HStack(spacing: DODSpacing.sm) {
                        Image(systemName: "birthday.cake.fill")
                            .foregroundStyle(DODColor.burntOrange)
                            .frame(width: 24)
                        Text(cake.title)
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.label)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DODColor.labelSecondary)
                    }
                    .padding(DODSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        DODColor.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cook-chooser-dump-\(cake.id)")
            }
        }
    }
}
