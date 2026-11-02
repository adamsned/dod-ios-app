import DODDesignSystem
import DODSupport
import SwiftUI

extension CookJournalView {
    /// DUT-976 — one tappable "Recap this cookout" row per cookout.
    @ViewBuilder var cookoutRecapRows: some View {
        ForEach(Self.recapGroups(cooks)) { group in
            NavigationLink {
                CookoutRecapView(group: group)
            } label: {
                Label("Recap this cookout — \(group.headline())", systemImage: "film.stack")
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.burntOrange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DODSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                            .fill(DODColor.surfaceElevated)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("journal-recap-\(Int(group.day.timeIntervalSince1970))")
        }
    }
}
