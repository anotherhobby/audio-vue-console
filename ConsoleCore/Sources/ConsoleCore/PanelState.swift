import Foundation
import HostAPI
import OpenAPIRuntime

/// The panel's state as the app shows it: the condition the agent reports and the few values the
/// Overview reads from the panel's sections (`panel-window`; design D7). Every value the host may
/// lack is optional, as the host reports it null and never as a placeholder (audio-vue
/// `control-state`, "What is not known is null").
public struct PanelState: Sendable, Equatable {
    /// The panel's condition, as the agent tells them apart (audio-vue `control-service`).
    public enum Condition: Sendable, Equatable {
        case up
        case down
        /// Answering, but drawing has stopped, not measuring.
        case stale
        case captureStopped
        case noAudio
    }

    /// A section of the state the Overview reads.
    public enum Section: String, Sendable, CaseIterable {
        case scene, capture, analysis, calibration, display
    }

    public var condition: Condition
    /// When the panel last answered.
    public var since: Date?
    /// The scene on screen, by its label; never handed back to the host as its identity.
    public var sceneName: String?
    public var captureDevice: String?
    public var rateHz: Int?
    public var analysisP99Ms: Double?
    public var analysisBudgetMs: Double?
    /// The calibration's status word as the host gives it, such as `calibrated`.
    public var calibrationStatus: String?
    public var calibrationAgeDays: Double?
    public var displayWidthPx: Int?
    public var displayHeightPx: Int?
    /// Each section the host reports as failed, with its reason (audio-vue `control-state`, "A
    /// section that fails is contained").
    public var unavailable: [Section: String] = [:]

    public init(condition: Condition) {
        self.condition = condition
    }

    /// One state message, as `/v1/events` pushes it and `/v1/state` answers it.
    public init(json: Data) throws(HostFailure) {
        let state: Components.Schemas.State
        do {
            state = try JSONDecoder().decode(Components.Schemas.State.self, from: json)
        } catch {
            throw .unexpectedAnswer
        }
        self.init(state)
    }

    init(_ state: Components.Schemas.State) {
        condition = Self.condition(state.condition)
        since = state.since.flatMap(Self.date)
        let sections = state.sections
        sceneName = sections.scene?.name
        captureDevice = sections.capture?.device
        rateHz = sections.capture?.rateHz
        analysisP99Ms = sections.analysis?.p99Ms
        analysisBudgetMs = sections.analysis?.budgetMs
        calibrationStatus = sections.calibration?.status
        calibrationAgeDays = sections.calibration?.ageDays
        displayWidthPx = sections.display?.widthPx
        displayHeightPx = sections.display?.heightPx
        let containers: [Section: OpenAPIObjectContainer?] = [
            .scene: sections.scene?.additionalProperties,
            .capture: sections.capture?.additionalProperties,
            .analysis: sections.analysis?.additionalProperties,
            .calibration: sections.calibration?.additionalProperties,
            .display: sections.display?.additionalProperties,
        ]
        unavailable = containers.compactMapValues { $0?.value["unavailable"] as? String }
    }

    private static func condition(_ payload: Components.Schemas.State.ConditionPayload)
        -> Condition
    {
        switch payload {
        case .up: .up
        case .down: .down
        case .stale: .stale
        case .captureStopped: .captureStopped
        case .noAudio: .noAudio
        }
    }

    private static func date(_ text: String) -> Date? {
        do {
            return try Date(text, strategy: .iso8601)
        } catch {
            return nil
        }
    }
}
