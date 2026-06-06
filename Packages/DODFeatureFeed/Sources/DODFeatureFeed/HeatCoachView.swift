import DODDesignSystem
import DODSupport
import SwiftUI

/// **Dutch Oven Heat Coach** (DUT-48) — a starting coal estimate, condition
/// adjustments, and a cook-by-feel reference.
///
/// This screen embodies Dutch Oven Daddy's published method (the
/// `/dutch-oven-temperature-chart/` page): *stop using the chart; give a
/// starting point, then adapt by feel.* The estimate is framed everywhere as
/// "a starting point, not a rule," and the layout leads the cook toward the
/// feel cues — which are the point of the feature, not the number.
///
/// Self-contained: no data model, no CloudKit, no network. All input state
/// lives in `@State`; the displayed copy derives purely from
/// ``HeatCoachModel`` over ``DutchOvenHeatCoach`` (DODSupport). It is reached
/// via a `NavigationLink` row in the Settings "Tools" section (v1 low-risk
/// entry point — a dedicated Tools tab is the eventual home).
///
/// Hosted in `DODFeatureFeed` (the module that already owns ``SettingsView``)
/// so v1 ships without wiring a new SPM module/target. The adjustment,
/// feel-cue, and coal-management sections live in `HeatCoachView+Sections.swift`
/// so this file stays under the 400-line `file_length` cap.
///
/// Spec trace: DUT-48 (Dutch Oven Heat Coach).
public struct HeatCoachView: View {

    @State private var ovenDiameterInches: Int = 12
    @State private var style: CookingStyle = .even
    @State private var elevationFeet: Int = 0
    @State private var ambient: AmbientCondition = .mild
    @State private var windy: Bool = false

    public init() {}

    /// Rebuilt on every input change — pure value type, no retained state.
    private var coachModel: HeatCoachModel {
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
                inputsCard
                resultCard
                adjustmentsCard(coachModel)
                feelReferenceSection
                coalManagementSection
            }
            .padding(DODSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DODColor.surface)
        .navigationTitle("Heat Coach")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("heat-coach")
    }

    // MARK: - Inputs

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader("Your setup")

            labeledRow("Oven size") {
                Picker("Oven size", selection: $ovenDiameterInches) {
                    ForEach(HeatCoachModel.ovenSizes, id: \.self) { size in
                        Text("\(size)\"").tag(size)
                    }
                }
                .pickerStyle(.menu)
                .tint(DODColor.accent)
                .accessibilityIdentifier("heat-coach-oven-size")
            }

            labeledRow("Cooking style") {
                Picker("Cooking style", selection: $style) {
                    Text("Even").tag(CookingStyle.even)
                    Text("Baking").tag(CookingStyle.baking)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("heat-coach-style")
            }

            Divider().overlay(DODColor.surfaceDivider)

            elevationRow
            ambientRow
            windRow
        }
        .padding(DODSpacing.md)
        .cardSurface()
    }

    private var elevationRow: some View {
        labeledRow("Elevation") {
            Stepper(value: $elevationFeet, in: 0...15000, step: 500) {
                Text(elevationFeet == 0 ? "Sea level" : "\(elevationFeet) ft")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
            }
            .accessibilityIdentifier("heat-coach-elevation")
        }
    }

    private var ambientRow: some View {
        labeledRow("Air temperature") {
            Picker("Air temperature", selection: $ambient) {
                Text("Hot").tag(AmbientCondition.hot)
                Text("Mild").tag(AmbientCondition.mild)
                Text("Cold").tag(AmbientCondition.cold)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("heat-coach-ambient")
        }
    }

    private var windRow: some View {
        Toggle(isOn: $windy) {
            Text("Windy day")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
        }
        .tint(DODColor.accent)
        .accessibilityIdentifier("heat-coach-wind")
    }

    // MARK: - Result card ("a starting point — then cook by feel")

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("A starting point — then cook by feel")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelOnAccent.opacity(0.9))
                .textCase(.uppercase)

            Text(coachModel.coalHeadline)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.labelOnAccent)
                .fixedSize(horizontal: false, vertical: true)

            Text(coachModel.styleNote)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelOnAccent.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                .fill(DODColor.accent)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("heat-coach-result")
    }

    // MARK: - Shared building blocks

    /// Section header used across the screen's cards.
    @ViewBuilder
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .dodFont(DODType.displayMedium)
            .foregroundStyle(DODColor.label)
    }

    /// A label on top of an arbitrary control, stacked so the segmented /
    /// menu pickers get full width under their caption.
    @ViewBuilder
    private func labeledRow<Control: View>(
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
}

// MARK: - Card surface modifier

extension View {
    /// The brand card treatment shared by every Heat Coach section:
    /// `surfaceElevated` fill clipped to a continuous rounded rectangle,
    /// matching ``RecipeCard`` and the rest of the app's card register.
    func cardSurface() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                    .fill(DODColor.surfaceElevated)
            )
    }
}

#Preview("Heat Coach") {
    NavigationStack {
        HeatCoachView()
    }
}
