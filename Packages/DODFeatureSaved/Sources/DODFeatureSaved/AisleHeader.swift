import DODDesignSystem
import DODSupport
import SwiftUI

// MARK: - Inline aisle section header (T-680c hoists this to a DesignSystem primitive)

// Split out of `ShoppingListView.swift` to keep that file under SwiftLint's
// `file_length` cap.
//
// DUT-535 — `internal` (was `private`) so `AddToShoppingListSheet` reuses the
// same aisle display-name + glyph mapping, keeping the selection sheet's section
// headers identical to the Shopping List's.
struct AisleHeader: View {
    let aisle: IngredientAisleClassifier.Aisle

    var body: some View {
        Label {
            Text(Self.displayName(aisle))
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
        } icon: {
            Image(systemName: Self.glyph(aisle))
                .foregroundStyle(DODColor.accent)
        }
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
    }

    /// AC-39.4 display names for the six shipped aisles. `meat` renders as
    /// "Meat & Seafood" per AC-39.4 (the logic core folds seafood into `.meat`
    /// per CL-80). DUT-693 — the switch lives once on ``ShoppingListFormatter``
    /// (the pure, unit-tested home); this delegates so the header + the share
    /// text can never drift.
    static func displayName(_ aisle: IngredientAisleClassifier.Aisle) -> String {
        ShoppingListFormatter.displayName(aisle)
    }

    /// AC-39.4 per-aisle SF Symbol glyphs (mapped for the six shipped cases).
    /// Pantry uses `archivebox` rather than AC-39.4's `cabinet` because
    /// `cabinet` is not a valid SF Symbol (it would render blank); T-680c can
    /// revisit if a real pantry glyph ships.
    static func glyph(_ aisle: IngredientAisleClassifier.Aisle) -> String {
        switch aisle {
        case .produce: "leaf"
        case .meat: "fish"
        case .dairy: "drop"
        case .pantry: "archivebox"
        case .spices: "flame"
        case .other: "cart"
        }
    }
}
