import DODDesignSystem
import DODSupport
import SwiftUI

/// **Dutch Oven Heat Coach** (DUT-48; redesigned CL-274) — a starting coal
/// estimate, condition adjustments, and a cook-by-feel reference.
///
/// This screen embodies Dutch Oven Daddy's published method (the
/// `/dutch-oven-temperature-chart/` page): *stop using the chart; give a
/// starting point, then adapt by feel.* The estimate is framed everywhere as
/// "a starting point, not a rule."
///
/// **CL-274 redesign.** The old single long scroll (setup + result + adjustments
/// + feel cues + coal management, all stacked) is split into three jump-to pages
/// via a segmented switcher, to match the other Cooking Tools and so a beginner
/// gets the answer first instead of scrolling past everything:
///   - **Coals** — the answer: a compact setup → the coal estimate → optional
///     condition fine-tuning + the adjustment notes.
///   - **Feel** — the cook-by-feel cues (the heart of the method).
///   - **Tips** — coal-management habits + wind guidance.
/// Every option and guide is preserved; the copy (pinned by the DODSupport
/// tests) is unchanged. The page compositions live in `HeatCoachView+Sections`.
///
/// Self-contained: no data model, no CloudKit, no network. All input state lives
/// in `@State`; the displayed copy derives purely from ``HeatCoachModel`` over
/// ``DutchOvenHeatCoach`` (DODSupport). Reached from the Feed's Cooking Tools
/// menu + the Settings Tools row.
///
/// Spec trace: DUT-48 (Dutch Oven Heat Coach).
public struct HeatCoachView: View {

    /// The three jump-to pages, switched by ``pageSwitcher``. Coals is the
    /// answer; Feel + Tips are the guides.
    enum Page: Hashable, CaseIterable { case coals, feel, tips }

    @State private var page: Page = .coals
    // Non-private so the input cards in `+Sections` can bind to them ($-projections).
    @State var ovenDiameterInches: Int = 12
    @State var style: CookingStyle = .even
    @State var elevationFeet: Int = 0
    @State var ambient: AmbientCondition = .mild
    @State var windy: Bool = false
    /// CL-275 — the coach is presented as a sheet (Feed Cooking Tools + the
    /// First Cookout fire step), so it needs an explicit Done like the other
    /// tools, not just swipe-to-dismiss.
    @Environment(\.dismiss) private var dismiss

    public init() {}

    /// Rebuilt on every input change — pure value type, no retained state.
    /// Non-private so the page compositions in `+Sections` can read it.
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
            VStack(alignment: .leading, spacing: DODSpacing.lg) {
                Text(
                    "Managing heat is the trickiest part of Dutch oven cooking. The Heat "
                        + "Coach gives you a solid starting point for how many coals to use "
                        + "and where they go, then teaches you to read the cook by feel and "
                        + "adjust as you go, so you cook with confidence instead of guesswork."
                )
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)

                pageSwitcher

                switch page {
                case .coals:
                    setupCard
                    resultCard
                    conditionsCard(coachModel)
                case .feel:
                    feelReferenceSection
                case .tips:
                    coalManagementSection
                }
            }
            .padding(DODSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: page)
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

    /// Top-level page switcher. Reuses the brand ``accentSelector`` so the chosen
    /// page reads in the app's orange, consistent with the input selectors below.
    private var pageSwitcher: some View {
        accentSelector(
            selection: $page,
            options: [(.coals, "Coals"), (.feel, "Feel"), (.tips, "Tips")],
            accessibilityID: "heat-coach-pages"
        )
    }

    // MARK: - Shared building blocks (used across both files)

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
    /// so the page switcher + the `+Sections` input cards share one control.
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
                        // CL-304 / DUT-537 — segmented-pill control: the selected
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
            // CL-304 / DUT-537 — segmented-pill control track → Capsule pill.
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
