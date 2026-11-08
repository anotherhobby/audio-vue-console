import Foundation

/// What the Panel page's Status, Capture and Calibration sections say, as text, decided here so the
/// dash rule is under test (`panel-window`, "A value not read shows a dash"; design D7). A value
/// not read from the host is `dash`, every value is while the app is not paired, and nothing
/// made up or remembered stands in for one.
public struct PanelRows: Sendable, Equatable {
    public static let dash = "—"
    /// The Status section's title, which the page also offers Reset under.
    public static let statusTitle = "Status"

    public struct Row: Sendable, Equatable, Identifiable {
        public let label: String
        public let value: String
        /// Whether what the row reports is under way, shown with an indicator that it is working.
        public var working = false
        /// Whether the row reports something wrong, shown in a warning colour.
        public var warning = false
        public var id: String { label }
    }

    public struct Section: Sendable, Equatable {
        public let title: String
        public let rows: [Row]
        /// Why a section of the host's state could not be read, where the host said so.
        public let note: String?
    }

    public let status: Section
    public let capture: Section
    public let calibration: Section

    /// The sections for a host, its panel's state and the app's renderer, each nil where it has not
    /// been read, as while not paired. `time` writes the time a down panel last answered.
    public init(
        host: HostIdentity?, state: PanelState?, renderer: Renderer.Phase? = nil,
        cardCode: CardCodeVerdict? = nil,
        time: (Date) -> String = { $0.formatted(date: .omitted, time: .shortened) }
    ) {
        let unavailable = state?.unavailable ?? [:]
        let width = state?.displayWidthPx ?? host?.widthPx
        let height = state?.displayHeightPx ?? host?.heightPx
        status = Section(
            title: Self.statusTitle,
            rows: [
                Row(label: "Condition", value: Self.text(state.map { Self.condition($0, time) })),
                Row(label: "Scene", value: Self.text(state?.sceneName)),
                Row(label: "Display", value: Self.text(Self.size(width, height))),
                Self.renderer(renderer, cardCode),
            ],
            note: Self.note(unavailable, [.scene, .display]))
        capture = Section(
            title: "Capture",
            rows: [
                Row(label: "Device", value: Self.text(state?.captureDevice)),
                Row(label: "Rate", value: Self.text(state?.rateHz.map(Self.rate))),
                Row(label: "Analysis", value: Self.text(state.flatMap(Self.analysis))),
            ],
            note: Self.note(unavailable, [.capture, .analysis]))
        calibration = Section(
            title: "Calibration",
            rows: [
                Row(label: "Status", value: Self.text(state?.calibrationStatus.map(Self.status))),
                Row(label: "Age", value: Self.text(state?.calibrationAgeDays.map(Self.age))),
            ],
            note: Self.note(unavailable, [.calibration]))
    }

    public var sections: [Section] { [status, capture, calibration] }

    private static func text(_ value: String?) -> String {
        value ?? dash
    }

    /// The renderer's row (`panel-window`, "Status says whether scenes can be drawn"): ready only
    /// once the helper's code is the panel's, and a warning where it cannot draw as the panel does.
    private static func renderer(_ phase: Renderer.Phase?, _ code: CardCodeVerdict?) -> Row {
        let label = "Renderer"
        switch phase {
        case nil, .idle?: return Row(label: label, value: dash)
        case .starting?: return Row(label: label, value: "Starting…", working: true)
        case .preparing?: return Row(label: label, value: "Making the first frame…", working: true)
        case .failed(let reason)?:
            return Row(label: label, value: "Could not start: \(reason)", warning: true)
        case .ready?: return codeRow(label, code)
        }
    }

    /// A ready renderer's row, as the card code compares with the panel's.
    private static func codeRow(_ label: String, _ code: CardCodeVerdict?) -> Row {
        switch code {
        case nil:
            return Row(label: label, value: "Checking the card code…", working: true)
        case .same?:
            return Row(label: label, value: "Ready")
        case .damagedBundle?:
            return Row(
                label: label, value: "Not drawing: this app's render bundle is damaged",
                warning: true)
        case .unreadable?:
            return Row(
                label: label, value: "Not drawing: the panel's card code can't be read",
                warning: true)
        case .differs(let drift)? where drift.sharesNothing:
            return Row(
                label: label,
                value: "Not drawing: card code differs from the panel's. Scenes says which.",
                warning: true)
        case .differs?:
            return Row(
                label: label,
                value: "Ready, but some cards differ from the panel's. Scenes says which.",
                warning: true)
        }
    }

    /// The condition in words; `stale` is drawing stopped, not measuring (audio-vue
    /// `control-service`).
    private static func condition(_ state: PanelState, _ time: (Date) -> String) -> String {
        switch state.condition {
        case .up: "Up"
        case .down: state.since.map { "Down since \(time($0))" } ?? "Down"
        case .stale: "Not drawing"
        case .captureStopped: "Capture stopped"
        case .noAudio: "No audio"
        }
    }

    private static func size(_ width: Int?, _ height: Int?) -> String? {
        guard let width, let height else { return nil }
        return "\(width) × \(height)"
    }

    private static let hertzPerKilohertz = 1000.0

    private static func rate(_ hertz: Int) -> String {
        let kilohertz = Double(hertz) / hertzPerKilohertz
        return "\(kilohertz.formatted(.number.precision(.fractionLength(0...1)))) kHz"
    }

    private static func analysis(_ state: PanelState) -> String? {
        guard let time = state.analysisP99Ms else { return nil }
        let millis = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
        guard let budget = state.analysisBudgetMs else { return "\(time.formatted(millis)) ms" }
        return "\(time.formatted(millis)) ms of a \(budget.formatted(millis)) ms budget"
    }

    /// The words for the statuses audio-vue gives today, and the host's own text for any other,
    /// since the contract types it as a plain string.
    private static func status(_ status: String) -> String {
        switch status {
        case "calibrated": "Calibrated"
        case "stale": "Stale"
        case "shifted_by_hand": "Shifted by hand"
        case "obsolete": "Obsolete"
        case "uncalibrated": "Uncalibrated"
        default: status
        }
    }

    private static func age(_ days: Double) -> String {
        let whole = Int(days.rounded(.down))
        return whole == 1 ? "1 day" : "\(whole) days"
    }

    /// Why the state's `sections` read here could not be read, where the host said.
    private static func note(
        _ unavailable: [PanelState.Section: String], _ sections: [PanelState.Section]
    ) -> String? {
        let reasons = sections.compactMap { unavailable[$0] }
        return reasons.isEmpty ? nil : "Unavailable: " + reasons.joined(separator: "; ")
    }
}
