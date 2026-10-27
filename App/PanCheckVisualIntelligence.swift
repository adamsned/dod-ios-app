import AppIntents
import DODSupport
import Foundation

/// DUT-1826 — one pan-check result, surfaced to Visual Intelligence. `id` is `PanCheck.Verdict.rawValue`.
@available(iOS 26.0, *)
struct PanCheckEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Pan Check")
    static let defaultQuery = PanCheckQuery()

    let id: String

    var verdict: PanCheck.Verdict { PanCheck.Verdict(rawValue: id) ?? .unclear }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(verdict.headline)", subtitle: "\(verdict.advice)")
    }
}

@available(iOS 26.0, *)
struct PanCheckQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PanCheckEntity] {
        identifiers.map { PanCheckEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [PanCheckEntity] { [] }
}
