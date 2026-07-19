import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-194 / CL-265 — the "Your First Cookout" guided-path chooser. Redesigned
/// from a plain grouped `List` into a vertical **roadmap**: a large title +
/// subheader that frame the learning journey, the curated rungs rendered as a
/// connected path of tappable dish cards (each node showing the cook's progress
/// — done / current / upcoming, derived from the recommended rung), and the
/// off-path dump cakes as an "Anytime Treats" section. Picking any card swaps
/// this screen in place for the full paged ``FirstCookoutView`` (a dump cake
/// uses the generic `GuidedCookout.dumpCake` template). Reads
/// ``GuidedCookout/path`` dynamically, so new rungs
/// appear on the path for free.
///
/// T-912 / DUT-551 (CL-306) — `public` so the app-level Cooking Tools hub
/// (`App/CookingToolsHubView.swift`) can present the same roadmap the retired
/// Feed "Cooking Tools" menu used for its "Your First Cookout" row.
public struct CookChooserFlow: View {

    /// The progress-aware default (FeedView's `currentRung`) — the cook's
    /// current spot on the path. `nil` once every rung is cooked (a graduate).
    let recommended: GuidedCookout?
    /// DUT-381 — recipe ids the cook has actually logged, so a rung they cooked
    /// out of order still renders as done (the roadmap is freely tappable).
    var cookedRecipeIDs: Set<Int> = []
    /// DUT — when `true`, the chooser scrolls straight to the "Anytime Treats"
    /// (dump cakes) section on appear, instead of landing at the roadmap top.
    /// Set only by the Feed hero's "Or Cook a Dump Cake" CTA, which asks for the
    /// dump cakes directly; the primary "Start" CTA + every other entry point
    /// leave it `false` and keep today's top-of-roadmap landing.
    var scrollToDumpCakes: Bool = false
    let onLogCook: (CookLogEntry) -> Void

    /// T-912 / DUT-551 (CL-306) — `public` initializer so the app-level Cooking
    /// Tools hub can construct this outside the package (the Feed's own call
    /// sites use the memberwise init, which stays available in-module).
    public init(
        recommended: GuidedCookout?,
        cookedRecipeIDs: Set<Int> = [],
        scrollToDumpCakes: Bool = false,
        onLogCook: @escaping (CookLogEntry) -> Void
    ) {
        self.recommended = recommended
        self.cookedRecipeIDs = cookedRecipeIDs
        self.scrollToDumpCakes = scrollToDumpCakes
        self.onLogCook = onLogCook
    }

    /// DUT — the scroll anchor stamped on the "Anytime Treats" section so the
    /// dump-cake CTA can jump the chooser to it via `ScrollViewReader`.
    private static let anytimeTreatsAnchorID = "cook-chooser-anytime-treats"

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
    /// DUT — honor Reduce Motion when auto-scrolling to the Anytime Treats
    /// section: animate the jump for everyone else, snap instantly if set.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        Group {
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
        // DUT-624 — drive the SHARED bake-timer engine from the HOST, not from
        // the child `FirstCookoutView`'s own `.task`. That child's tick loop is
        // cancelled the instant the cook taps "Back to the path" (the view is
        // torn down), so a guided bake would freeze — never reaching "Timer's
        // Up!" — while the roadmap is on screen. This host-level `.task` outlives
        // any single child, so the countdown keeps advancing to `.finished`
        // regardless of which child view is mounted. Idempotent alongside the
        // child's own tick (a `refresh()` on an already-finished timer no-ops).
        .task { await tickTimerEngine() }
    }

    /// DUT-624 — advance the shared engine ~1×/s for as long as the guided path
    /// (this host) is on screen, so a running bake finishes even while the cook
    /// is browsing the roadmap rather than the recipe flow.
    private func tickTimerEngine() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            timerEngine.refresh()
        }
    }

    private var picker: some View {
        NavigationStack {
            ScrollViewReader { proxy in
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
                // DUT — the Feed hero's "Or Cook a Dump Cake" CTA opens this
                // chooser asking to land on the dump cakes, not the roadmap top.
                // Jump to the Anytime Treats anchor once the picker appears; the
                // primary "Start" CTA leaves `scrollToDumpCakes` false and keeps
                // the top-of-roadmap landing untouched.
                .onAppear {
                    guard scrollToDumpCakes else { return }
                    withAnimation(reduceMotion ? nil : .default) {
                        proxy.scrollTo(Self.anytimeTreatsAnchorID, anchor: .top)
                    }
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

    /// Pure, testable rung → locked mapping (DUT-1235): only the campfire
    /// capstone can ever be locked, and only while neither home rung before it
    /// has been cooked yet. Every other rung is never locked.
    nonisolated static func isRungLocked(_ rung: GuidedCookout, cookedRecipeIDs: Set<Int> = []) -> Bool {
        rung.isCampfire && GuidedCookout.isCampfireLocked(cookedRecipeIDs: cookedRecipeIDs)
    }

    @ViewBuilder private var pathSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(pathRungs.enumerated()), id: \.element.recipeID) { index, rung in
                CookPathNode(
                    rung: rung,
                    number: index + 1,
                    state: nodeState(index),
                    isLast: index == pathRungs.count - 1,
                    isLocked: Self.isRungLocked(rung, cookedRecipeIDs: cookedRecipeIDs)
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
                    // DUT — scroll anchor for the dump-cake CTA's jump-on-appear.
                    .id(Self.anytimeTreatsAnchorID)
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
