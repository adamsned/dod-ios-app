import Foundation

/// One step in a cast-iron care walkthrough.
public struct CareStep: Codable, Sendable, Equatable, Identifiable {
    /// 1-based position in the ordered walkthrough.
    public var id: Int
    public var title: String
    public var detail: String

    public init(id: Int, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

/// The structured result of a cast-iron photo diagnosis. A plain value type
/// so the app, the curated fallback, and the (iOS 27) on-device model all
/// speak one contract - the Foundation Models diagnoser maps its `@Generable`
/// output into this (see `FoundationModelsCastIronDiagnoser`, staged behind
/// `CASTIRON_IOS27`).
public struct CastIronDiagnosis: Codable, Sendable, Equatable {
    public var condition: CastIronCondition
    /// 0...1 confidence the photo is cast iron and the condition is correct.
    public var confidence: Double
    /// One or two beginner-friendly sentences about what was observed.
    public var summary: String
    /// Ordered care/restore steps, most important first.
    public var steps: [CareStep]
    /// A safety caveat when relevant (e.g. a crack -> stop cooking on it).
    public var safetyNote: String?
    /// How the diagnosis was produced - drives a disclosure line in the UI.
    public var source: Source

    public enum Source: String, Codable, Sendable {
        case onDeviceVision
        case privateCloudCompute
        case curated
    }

    public init(
        condition: CastIronCondition,
        confidence: Double,
        summary: String,
        steps: [CareStep],
        safetyNote: String? = nil,
        source: Source
    ) {
        self.condition = condition
        self.confidence = confidence
        self.summary = summary
        self.steps = steps
        self.safetyNote = safetyNote
        self.source = source
    }
}
