import DODDesignSystem
import SwiftUI

/// DUT-572 / CL-312 — the editorial info card that replaces `RecipeDetailMetaPills`.
///
/// Modeled on how the website presents a recipe: a stacked Prep / Cook / Total
/// Time block (big centered values with hairline dividers between present rows)
/// over a two-column Course / Cuisine / Diet / Servings / Calories / Author
/// grid. Every field is optional — only non-nil rows / cells render, and the
/// whole card collapses to `EmptyView` when nothing is present.
///
/// Lives in the feature package (NOT DODDesignSystem) so it stays out of the
/// CI-gated L4 snapshot suite. Reuses `DODColor` / `DODType` / `DODSpacing` /
/// `DODRadius`.
struct RecipeInfoCard: View {

    /// Resolved, display-ready optionals. The parent (`RecipeDetailView`) builds
    /// this from `viewModel.recipe`: times pre-formatted via the `format(duration:)`
    /// helper, arrays joined with ", ", diet values run through ``prettifyDiet``.
    struct Model: Equatable {
        var prepTime: String?
        var cookTime: String?
        var totalTime: String?
        var course: String?
        var cuisine: String?
        var diet: String?
        var servings: String?
        var calories: String?
        var author: String?

        /// True when there's nothing to show — the card no-ops.
        var isEmpty: Bool {
            prepTime == nil && cookTime == nil && totalTime == nil
                && course == nil && cuisine == nil && diet == nil
                && servings == nil && calories == nil && author == nil
        }
    }

    let model: Model

    /// DUT-573 / CL-313 — when non-nil, the Servings cell becomes INTERACTIVE:
    /// it shows the current user serving count with a compact −/+ stepper
    /// (folding in the old standalone `RecipeServingsScaler`, now deleted).
    /// When nil, the static `model.servings` string renders as before. Defaults
    /// keep previews / other callers source-compatible.
    var servingsBinding: Binding<Int>?
    /// Clamp range for the interactive stepper (mirrors the view model's
    /// `userServingsRange`). Ignored when `servingsBinding` is nil.
    var servingsRange: ClosedRange<Int> = 1...24
    /// Source `recipeYield` — shown as a "Recipe makes N." secondary line when
    /// the user has scaled away from it. Ignored when `servingsBinding` is nil.
    var sourceServings: Int = 0
    /// True when the user has scaled past the home-dutch-oven capacity
    /// threshold (CL-52) — drives the ">12 servings" warning caption under the
    /// card. Only rendered when `servingsBinding` is non-nil.
    var showsServingWarning: Bool = false

    /// A single time row: Title-Case label over a big centered value.
    private struct TimeRow: Identifiable {
        let label: String
        let value: String

        var id: String { label }
    }

    /// A single metadata cell: caption label over a body value. `isServings`
    /// flags the cell that becomes the interactive stepper when a
    /// `servingsBinding` is supplied (DUT-573 / CL-313).
    private struct MetaCell: Identifiable {
        let label: String
        let value: String
        var isServings = false

        var id: String { label }
    }

    private var timeRows: [TimeRow] {
        var rows: [TimeRow] = []
        if let prep = model.prepTime { rows.append(.init(label: "Prep Time", value: prep)) }
        if let cook = model.cookTime { rows.append(.init(label: "Cook Time", value: cook)) }
        if let total = model.totalTime { rows.append(.init(label: "Total Time", value: total)) }
        return rows
    }

    private var metaCells: [MetaCell] {
        var cells: [MetaCell] = []
        if let course = model.course { cells.append(.init(label: "Course", value: course)) }
        if let cuisine = model.cuisine { cells.append(.init(label: "Cuisine", value: cuisine)) }
        if let diet = model.diet { cells.append(.init(label: "Diet", value: diet)) }
        // DUT-573 / CL-313 — when a binding is present the Servings cell renders
        // the interactive stepper (the `value` string is unused for that cell,
        // it reads the live binding); otherwise the static `model.servings`.
        if let binding = servingsBinding {
            cells.append(.init(label: "Servings", value: "\(binding.wrappedValue)", isServings: true))
        } else if let servings = model.servings {
            cells.append(.init(label: "Servings", value: servings))
        }
        if let calories = model.calories { cells.append(.init(label: "Calories", value: calories)) }
        if let author = model.author { cells.append(.init(label: "Author", value: author)) }
        return cells
    }

    var body: some View {
        // Render whenever there's static content OR an interactive servings
        // binding (the stepper cell renders even if `model` is otherwise empty).
        if !model.isEmpty || servingsBinding != nil {
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                VStack(alignment: .leading, spacing: DODSpacing.md) {
                    timesBlock
                    if !timeRows.isEmpty, !metaCells.isEmpty {
                        Rectangle()
                            .fill(DODColor.surfaceDivider)
                            .frame(height: 1)
                    }
                    metadataGrid
                }
                .padding(DODSpacing.md)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                        .fill(DODColor.surfaceElevated)
                )
                // DUT-573 / CL-313 — the ">12 servings" capacity warning sits
                // UNDER the card (mirrors the old scaler's AC-31.6 caption).
                if servingsBinding != nil, showsServingWarning {
                    servingWarningCaption
                }
            }
            .padding(.horizontal, DODSpacing.md)
        }
    }

    /// DUT-573 / CL-313 — non-blocking dutch-oven capacity warning (AC-31.6),
    /// rendered under the card when the interactive servings count is >12.
    private var servingWarningCaption: some View {
        HStack(alignment: .top, spacing: DODSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DODColor.burntOrange)
                .accessibilityHidden(true)
            Text(
                "Most home dutch ovens (5-quart) cap out around 12 servings. "
                    + "Consider doubling the recipe in two batches instead."
            )
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DODSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Capacity warning. Most home dutch ovens cap out around 12 servings."
        )
    }

    @ViewBuilder
    private var timesBlock: some View {
        if !timeRows.isEmpty {
            VStack(spacing: DODSpacing.sm) {
                ForEach(Array(timeRows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(DODColor.surfaceDivider)
                            .frame(height: 1)
                    }
                    VStack(spacing: DODSpacing.xxs) {
                        Text(row.label)
                            .dodFont(DODType.caption)
                            .foregroundStyle(DODColor.labelSecondary)
                        Text(row.value)
                            .dodFont(DODType.displayMedium)
                            .foregroundStyle(DODColor.labelStrong)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private var metadataGrid: some View {
        if !metaCells.isEmpty {
            let columns = [
                GridItem(.flexible(), alignment: .topLeading),
                GridItem(.flexible(), alignment: .topLeading),
            ]
            LazyVGrid(columns: columns, alignment: .leading, spacing: DODSpacing.md) {
                ForEach(metaCells) { cell in
                    if cell.isServings, let binding = servingsBinding {
                        servingsStepperCell(binding: binding)
                    } else {
                        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                            Text(cell.label)
                                .dodFont(DODType.caption)
                                .foregroundStyle(DODColor.labelSecondary)
                            Text(cell.value)
                                .dodFont(DODType.body)
                                .foregroundStyle(DODColor.label)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    /// DUT-573 / CL-313 — the interactive Servings cell: the "Servings" label
    /// over the current count with a compact −/+ stepper, plus a "Recipe makes
    /// N." secondary line when the user has scaled away from the source yield.
    /// Reuses the visual language of the old `RecipeServingsScaler` (US-31 /
    /// AC-31.1 / AC-31.2). The `Stepper` clamps to `servingsRange`.
    private func servingsStepperCell(binding: Binding<Int>) -> some View {
        let value = binding.wrappedValue
        return VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text("Servings")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            HStack(spacing: DODSpacing.sm) {
                Text("\(value)")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                Stepper("Servings", value: binding, in: servingsRange, step: 1)
                    .labelsHidden()
            }
            if value != sourceServings, sourceServings > 0 {
                Text("Recipe makes \(sourceServings).")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // DUT-614: present as ONE adjustable control so VoiceOver can change the
        // count, mirroring the StarRating (DUT-409) idiom. `.combine` with no
        // adjustable action read "Servings, N" with no way to increment.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Servings")
        .accessibilityValue("\(value)")
        // Stable test handle for the L5 E2E servings-scaler journey. The old
        // `Text("Serves 4")` + inner `Stepper` buttons the test drove no longer
        // exist (DUT-573 / DUT-614 collapsed this into one adjustable element);
        // the test now locates this element by identifier, reads its value, and
        // drives the adjustable increment action.
        .accessibilityIdentifier("recipe.servings")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                binding.wrappedValue = min(value + 1, servingsRange.upperBound)
            case .decrement:
                binding.wrappedValue = max(value - 1, servingsRange.lowerBound)
            @unknown default:
                break
            }
        }
        // Light selection tick on each servings change (SwiftUI's `Stepper`
        // ships no haptic of its own). Matches the app's `.selection` vocabulary
        // for discrete controls and also covers the VoiceOver adjustable path.
        .sensoryFeedback(.selection, trigger: value)
    }

    /// DUT-572 / CL-312 — prettify a `suitableForDiet` value. The parser stores
    /// these raw, and they are frequently schema.org URLs
    /// (`https://schema.org/LowLactoseDiet`). Takes the last path component,
    /// strips a trailing "Diet", and splits camelCase into words
    /// ("LowLactoseDiet" → "Low Lactose"). Bare strings that aren't URLs pass
    /// through unchanged.
    static func prettifyDiet(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("schema.org") || trimmed.contains("/") else {
            return trimmed
        }
        // Last path component of a URL-ish token.
        var token =
            trimmed.split(separator: "/").last.map(String.init) ?? trimmed
        if token.hasSuffix("Diet") {
            token.removeLast("Diet".count)
        }
        return splitCamelCase(token)
    }

    /// Split a camelCase / PascalCase token into space-separated words.
    /// "LowLactose" → "Low Lactose". A non-camelCase token returns unchanged.
    static func splitCamelCase(_ token: String) -> String {
        guard !token.isEmpty else { return token }
        var result = ""
        for (index, character) in token.enumerated() {
            if index > 0, character.isUppercase {
                result.append(" ")
            }
            result.append(character)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
