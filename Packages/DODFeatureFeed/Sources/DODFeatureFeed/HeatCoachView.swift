import DODDesignSystem
import DODSupport
import SwiftUI

/// **Dutch Oven Heat Coach** (DUT-48; redesigned DUT-584, DUT-598) — a starting
/// coal estimate, condition adjustments, and a cook-by-feel reference.
///
/// This screen embodies Dutch Oven Daddy's published method (the
/// `/dutch-oven-temperature-chart/` page): *stop using the chart; give a
/// starting point, then adapt by feel.* The estimate is framed everywhere as
/// "a starting point, not a rule."
///
/// **DUT-598 interface overhaul.** DUT-584 was already answer-first, but the
/// screen still read as a wall of equal-weight cards (the wordy style note lived
/// in the hero, and the six feel cues floated as six separate cards). This pass
/// keeps the same computed answer + copy and tightens the information hierarchy:
///   1. **Hero result** — the big coal total + the visual coal-split diagram,
///      and nothing else competing with it. The recipe context, when seeded,
///      sits under the number as one quiet line.
///   2. **Setup** — the two controls that drive the answer (Oven Size stepper +
///      Cooking Style pills) sit directly under the result, with the style note
///      as a helper caption at the point of choice (moved out of the hero).
///   3. **Adjust for Conditions** — optional, collapsed (elevation / air temp /
///      wind + the adjustment notes).
///   4. **Cook by Feel** — the six cues consolidated into ONE card of compact
///      rows (was six cards), still always visible: the heart of the method.
///   5. **Coal Management & Wind** — collapsed, below.
/// Every option and guide is preserved; the copy (pinned by the DODSupport
/// tests) is unchanged. The compositions live in `HeatCoachView+Sections` and
/// the diagram in `HeatCoachView+Diagram`.
///
/// **Recipe-prefill (DUT-584).** ``init(seed:)`` accepts an optional
/// ``HeatCoachSeed`` so the coach can open pre-answered from a recipe: the nudge
/// hands it oven diameter (12") + a style derived from the recipe's task, plus
/// the recipe's target °F for a context line on the answer. Standalone opens
/// (the Cooking Tools hub tile, the First Cookout fire step) pass `nil` and keep
/// today's 12"/even default.
///
/// Self-contained: no data model, no CloudKit, no network. All input state lives
/// in `@State`; the displayed copy derives purely from ``HeatCoachModel`` over
/// ``DutchOvenHeatCoach`` (DODSupport). Reached from the Cooking Tools hub +
/// the per-recipe nudge.
///
/// Spec trace: DUT-48 (Dutch Oven Heat Coach), DUT-584 (answer-first revamp).
public struct HeatCoachView: View {

    // Non-private so the input cards in `+Sections` can bind to them ($-projections).
    @State var ovenDiameterInches: Int
    @State var style: CookingStyle
    @State var elevationFeet: Int = 0
    @State var ambient: AmbientCondition = .mild
    @State var windy: Bool = false
    /// DUT-584 — expands the optional conditions group (default collapsed so the
    /// answer isn't buried under fine-tuning most cooks never need).
    @State var showConditions = false
    /// DUT-584 — expands the coal-management + wind tips group (default collapsed
    /// — reachable, but not competing with the answer).
    @State var showTips = false
    /// v2 redesign — the single expanded cook-by-feel cue (accordion; nil = all
    /// collapsed). Progressive disclosure keeps that section a scannable column
    /// of sensory cues instead of a wall of always-open rows.
    @State var expandedFeelCue: String?

    /// DUT-584 — the recipe's target temperature, for the answer card's context
    /// line ("For this recipe at 350°F"). `nil` on a standalone open.
    let seedTemperatureF: Int?

    /// DUT-275 — the coach is presented as a sheet (hub + the First Cookout fire
    /// step + the per-recipe nudge), so it needs an explicit Done like the other
    /// tools, not just swipe-to-dismiss.
    @Environment(\.dismiss) private var dismiss

    /// Honor Reduce Motion for the section-expand + cue-accordion transitions.
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Standalone open — 12" / even default, no recipe context.
    public init() {
        self.init(seed: nil)
    }

    /// DUT-584 — open pre-answered from a recipe when `seed` is non-nil, else the
    /// standalone 12" / even default.
    public init(seed: HeatCoachSeed?) {
        _ovenDiameterInches = State(initialValue: seed?.ovenDiameterInches ?? 12)
        _style = State(initialValue: seed?.style ?? .even)
        seedTemperatureF = seed?.targetTemperatureF
    }

    /// Rebuilt on every input change — pure value type, no retained state.
    /// Non-private so the compositions in `+Sections` / `+Diagram` can read it.
    var coachModel: HeatCoachModel {
        HeatCoachModel(
            ovenDiameterInches: ovenDiameterInches,
            style: style,
            elevationFeet: elevationFeet,
            ambient: ambient,
            windy: windy
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DODSpacing.md) {
                // The result + the controls that drive it read as one connected
                // unit at the top (tight spacing), then the reference sections
                // step down below with a little more air between them.
                answerCard
                primaryInputsCard
                    .padding(.bottom, DODSpacing.xs)
                conditionsGroup(coachModel)
                feelReferenceSection
                tipsGroup
            }
            .padding(DODSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showConditions)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showTips)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: expandedFeelCue)
        }
        .background(DODColor.surface)
        .navigationTitle("Heat Coach")
        .dodInlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .tint(DODColor.burntOrange)
            }
        }
        .accessibilityIdentifier("heat-coach")
    }

    // MARK: - Shared building blocks (used across the +Sections / +Diagram files)

    /// Section header used across the screen's cards.
    @ViewBuilder
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .dodFont(DODType.displayMedium)
            .foregroundStyle(DODColor.label)
    }

    /// A label stacked on top of a control so the menu / segmented pickers get
    /// full width under their caption. Non-private for the `+Sections` cards.
    @ViewBuilder
    func labeledRow<Control: View>(
        _ label: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(label)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            control()
        }
    }

    /// Brand-accent segmented selector (DUT-83): selected = accent fill +
    /// `labelOnAccent`; unselected = clear over a recessed `surface` track with a
    /// hairline so it reads as a grouped control in both light + dark. Non-private
    /// so the `+Sections` input cards share one control.
    @ViewBuilder
    func accentSelector<Value: Hashable>(
        selection: Binding<Value>,
        options: [(Value, String)],
        accessibilityID: String
    ) -> some View {
        HStack(spacing: DODSpacing.xxs) {
            ForEach(options.indices, id: \.self) { index in
                let (value, label) = options[index]
                let isSelected = selection.wrappedValue == value
                Text(label)
                    .dodFont(DODType.body)
                    .frame(maxWidth: .infinity, minHeight: 44)  // DUT-291: 44pt tap target
                    .padding(.vertical, DODSpacing.xs)
                    .foregroundStyle(isSelected ? DODColor.labelOnAccent : DODColor.label)
                    .background(
                        // DUT-304 / DUT-537 — segmented-pill control: the selected
                        // segment is a Capsule nested inside the Capsule track below.
                        Capsule(style: .continuous)
                            .fill(isSelected ? DODColor.accent : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selection.wrappedValue = value }
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(DODSpacing.xxs)
        .background(
            // DUT-304 / DUT-537 — segmented-pill control track → Capsule pill.
            Capsule(style: .continuous)
                .fill(DODColor.surface)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(DODColor.surfaceDivider, lineWidth: 1)
        )
        .accessibilityIdentifier(accessibilityID)
    }
}

// MARK: - Card surface modifier

extension View {
    /// The brand card treatment shared by every Heat Coach section:
    /// `surfaceElevated` fill clipped to a continuous rounded rectangle.
    func cardSurface() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    .fill(DODColor.surfaceElevated)
            )
    }
}

#Preview("Heat Coach") {
    NavigationStack {
        HeatCoachView()
    }
}

#Preview("Heat Coach — recipe seed") {
    NavigationStack {
        HeatCoachView(
            seed: HeatCoachSeed(ovenDiameterInches: 12, style: .baking, targetTemperatureF: 350)
        )
    }
}
