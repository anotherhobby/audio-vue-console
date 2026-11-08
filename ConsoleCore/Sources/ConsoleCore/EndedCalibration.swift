/// The calibration that last ended, as the panel's state names it until the next arm lands
/// (audio-vue `control-state`, "The state names the calibration that last ended"). A run is matched
/// to its ending by the arm's id, never by a clock (design D3).
public struct EndedCalibration: Sendable, Equatable {
    public enum Outcome: String, Sendable, Equatable {
        /// The run completed and wrote its record.
        case done
        /// The run did not complete, and wrote no record.
        case failed
        /// No file was heard before the arm's deadline.
        case expired
        /// A cancel stopped it before it ended.
        case cancelled
    }

    /// The id the arm's done answer gave.
    public let arm: String
    public let outcome: Outcome
    public let kind: String?
    /// The record's run id, or nil where no record was written.
    public let runID: String?
    /// Whether the record could apply: false where its stimulus did not all arrive.
    public let applicable: Bool?
    /// Words for a person: why it failed or expired, which stimulus was missing, or that its
    /// report was not written.
    public let reason: String?

    public init(
        arm: String, outcome: Outcome, kind: String? = nil, runID: String? = nil,
        applicable: Bool? = nil, reason: String? = nil
    ) {
        self.arm = arm
        self.outcome = outcome
        self.kind = kind
        self.runID = runID
        self.applicable = applicable
        self.reason = reason
    }
}
