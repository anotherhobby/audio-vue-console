/// Whether Calibrate… can start a run, and at which rate, or why not (`calibration-run`, "Calibrate
/// is offered only where a run can work"; design D4). The app's audio-vue code must be the panel's,
/// so the file it renders is the one the panel listens for.
public enum CalibrationReadiness: Sendable, Equatable {
    case ready(rate: Int)
    case notReady(String)

    /// What the app knows of the panel, each nil where it has not been read.
    public init(
        paired: Bool, condition: PanelState.Condition?, verdict: CardCodeVerdict?,
        installedRate: Int?, underWay: Bool
    ) {
        if let reason = Self.reason(paired, condition, verdict, underWay) {
            self = .notReady(reason)
        } else if let installedRate {
            self = .ready(rate: installedRate)
        } else {
            self = .notReady("Reading the panel's capture rate…")
        }
    }

    private static func reason(
        _ paired: Bool, _ condition: PanelState.Condition?, _ verdict: CardCodeVerdict?,
        _ underWay: Bool
    ) -> String? {
        guard paired else { return "Pair with the panel to calibrate it." }
        guard !underWay else { return "A run is under way." }
        guard condition == .up else { return "The panel isn't running, so it can't be calibrated." }
        switch verdict {
        case nil: return "Checking this app's audio-vue code against the panel's…"
        case .same?: return nil
        case .differs?, .unreadable?, .damagedBundle?:
            return "This app and the panel run different audio-vue code, so the file it would play "
                + "isn't the one the panel listens for. Build the app from the code the panel runs."
        }
    }
}
