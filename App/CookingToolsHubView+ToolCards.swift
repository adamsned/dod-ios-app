import DODDesignSystem
import DODFeatureFeed
import SwiftUI

// DUT-551 (CL-306) — the six tool cards, extracted from `CookingToolsHubView`
// for the SwiftLint `type_body_length` cap (mirrors the `+TipBanner.swift`
// split). Replaces the prior single insetGrouped `List` `Section`: each tool is
// now its own card on `DODColor.surfaceElevated` (white in light, warm brown in
// dark — never the system grouped grey), with a larger circle-free icon.
extension CookingToolsHubView {

    /// The six tools, in meal-making order (shop → heat → cook → after), each as
    /// its own visually distinct card. `ScrollView` + `LazyVStack` (not a grouped
    /// `List`) so the cards read as separate cells on the brand surface instead of
    /// one shared grouped block. The intro caption (formerly the List section
    /// header) sits above the cards.
    var toolList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DODSpacing.md) {
                Text("Everything you need, in the order you'll use it.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .padding(.top, DODSpacing.xs)

                toolCard(
                    icon: "flame.fill",
                    title: "Your First Cookout",
                    description: "New to Dutch oven cooking? Get coached through a whole cook, "
                        + "start to finish.",
                    accessibilityID: "hub-first-cookout"
                ) { activeToolSheet = .firstCookout }

                toolCard(
                    icon: "cart.fill",
                    title: "Shopping List",
                    description: "Turn the recipes you're making into one aisle-sorted list, "
                        + "so you shop in a single loop.",
                    accessibilityID: "hub-shopping-list"
                ) {
                    if path.last != .shoppingList { path.append(.shoppingList) }
                }

                toolCard(
                    icon: "thermometer.medium",
                    title: "Heat Coach",
                    description: "Figure out how many coals your oven needs for any temperature, "
                        + "then adjust by feel.",
                    accessibilityID: "hub-heat-coach"
                ) { activeToolSheet = .heatCoach(seed: nil) }

                toolCard(
                    icon: "flame.circle.fill",
                    title: "Cook Mode",
                    description: "Cook any recipe hands-free, one step at a time, with timers "
                        + "and voice. Open a recipe and tap Cook Now to start.",
                    accessibilityID: "hub-cook-mode"
                ) { activeToolSheet = .cookModeExplainer }

                toolCard(
                    icon: "book.closed.fill",
                    title: "Cooking Journal",
                    description: "Log every cook with a photo and notes, and build your streak.",
                    accessibilityID: "hub-journal"
                ) { activeToolSheet = .cookingJournal }

                toolCard(
                    icon: "bag.fill",
                    title: "Buy BuzzyWaxx",
                    description: "Season and protect your cast iron with the wax we swear by.",
                    accessibilityID: "hub-buy-buzzywaxx"
                ) { openToolURL(SettingsViewModel.buyBuzzyWaxxURLString) }
            }
            // DUT-695 — cap the 6 tool cards to a readable centered column on
            // iPad (regular width) so they don't stretch edge-to-edge; compact
            // (iPhone) is returned unchanged.
            .readableContentColumn(horizontalSizeClass)
            .padding(.horizontal, DODSpacing.md)
            .padding(.bottom, DODSpacing.md)
        }
    }

    /// One hub tool card: a circle-free (larger) icon + Title-Case title +
    /// sentence-case description, wrapped as a full-width plain button on the
    /// brand `surfaceElevated` surface (white light / warm brown dark). A trailing
    /// `chevron.right` reads as the shared tappable-row affordance on EVERY tool
    /// card — DUT-597 — so the hub's rows are visually consistent (previously only
    /// the Shopping List push carried it, DUT-570). Every card here acts (opens a
    /// sheet, pushes a destination, or hands off to the browser), so all navigate.
    func toolCard(
        icon: String,
        title: String,
        description: String,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DODSpacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(DODColor.burntOrange)
                    .accessibilityHidden(true)  // DUT-693 — decorative glyph
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    Text(title)
                        .dodFont(DODType.heading)
                        .foregroundStyle(DODColor.label)
                    Text(description)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DODSpacing.sm)
                // DUT-597 — the trailing chevron now reads as the shared
                // tappable-row affordance on every tool card (same style, size, and
                // color the Shopping List row introduced in DUT-570), so the hub's
                // rows are visually consistent as navigation.
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .accessibilityHidden(true)  // DUT-693 — decorative affordance glyph
            }
            .padding(DODSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    .fill(DODColor.surfaceElevated)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // DUT-695 — trackpad/pointer lift on iPad; no-op without a pointer.
        .hoverEffect(.highlight)
        .accessibilityIdentifier(accessibilityID)
    }
}
