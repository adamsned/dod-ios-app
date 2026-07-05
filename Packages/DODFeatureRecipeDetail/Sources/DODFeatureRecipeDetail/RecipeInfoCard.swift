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

    /// A single time row: Title-Case label over a big centered value.
    private struct TimeRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    /// A single metadata cell: caption label over a body value.
    private struct MetaCell: Identifiable {
        let id = UUID()
        let label: String
        let value: String
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
        if let servings = model.servings { cells.append(.init(label: "Servings", value: servings)) }
        if let calories = model.calories { cells.append(.init(label: "Calories", value: calories)) }
        if let author = model.author { cells.append(.init(label: "Author", value: author)) }
        return cells
    }

    var body: some View {
        if !model.isEmpty {
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
            .padding(.horizontal, DODSpacing.md)
        }
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
