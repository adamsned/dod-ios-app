import DODSupport
import SwiftUI

enum BringListPresentation {
    static func displayName(_ category: BringListCategory) -> String {
        switch category {
        case .ovens: "Dutch Ovens"
        case .fuel: "Coals & Fuel"
        case .tools: "Tools"
        case .transport: "Table & Transport"
        case .other: "Other Gear"
        }
    }
}
