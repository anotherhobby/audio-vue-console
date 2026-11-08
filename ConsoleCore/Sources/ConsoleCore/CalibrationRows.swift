import Foundation

/// What the Calibration page says of the calibration in force, as text, with the Panel page's dash
/// rule and status words (`calibration-history`, "The page shows the calibration in force"). The
/// status word is also why none applies where none does: uncalibrated, obsolete or shifted by hand.
public struct CalibrationRows: Sendable, Equatable {
    public let inForce: PanelRows.Section

    /// The rows for the panel's state, nil where it has not been read.
    public init(state: PanelState?) {
        let text = PanelRows.text
        inForce = PanelRows.Section(
            title: "In Force",
            rows: [
                PanelRows.Row(
                    label: "Status", value: text(state?.calibrationStatus.map(PanelRows.status))),
                PanelRows.Row(
                    label: "Run", value: text(state?.calibrationRunID.map(RunEntry.title(forID:)))),
                PanelRows.Row(
                    label: "Age", value: text(state?.calibrationAgeDays.map(PanelRows.age))),
                PanelRows.Row(label: "Trim", value: text(state?.calibrationTrimDB.map(Self.trim))),
                PanelRows.Row(
                    label: "Noise Floor",
                    value: text(state?.calibrationNoiseFloorDBFS.map(Self.floor))),
            ],
            note: PanelRows.note(state?.unavailable ?? [:], [.calibration]))
    }

    /// A trim with its sign and two places, as `+0.01 dB`.
    private static func trim(_ decibels: Double) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
            .sign(strategy: .always())
        return "\(decibels.formatted(style)) dB"
    }

    /// A floor to one place, as `−118.4 dBFS`.
    private static func floor(_ level: Double) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
        return "\(level.formatted(style)) dBFS"
    }
}
