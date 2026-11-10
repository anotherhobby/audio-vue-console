import Testing

@testable import ConsoleCore

/// `scene-settings`, "The scene says when no calibration holds at its rate" (design D7).
struct CalibrationCoverageTests {
    private static let calibrations: [Int: CalibratedRate.Status] = [
        96_000: .calibrated, 48_000: .stale,
    ]

    private static func capturing(_ rate: Int) -> [String: JSONValue] {
        ["analysis": .object(["capture_rate": .integer(rate)])]
    }

    @Test func aCalibratedCaptureRateHasNoNote() {
        let note = CalibrationCoverage.note(
            for: Self.capturing(96_000), installed: 48_000, calibrations: Self.calibrations)
        #expect(note == nil)
    }

    @Test func anUncalibratedCaptureRateIsNamed() {
        let note = CalibrationCoverage.note(
            for: Self.capturing(44_100), installed: 96_000, calibrations: Self.calibrations)
        #expect(
            note == "No calibration holds at 44.1 kHz, so this scene's readings are uncalibrated.")
    }

    @Test func anUnsetCaptureRateUsesTheInstalledRate() {
        #expect(
            CalibrationCoverage.note(for: [:], installed: 96_000, calibrations: Self.calibrations)
                == nil)
        #expect(
            CalibrationCoverage.note(for: [:], installed: 192_000, calibrations: Self.calibrations)?
                .contains("192 kHz") == true)
    }

    @Test func aStaleRecordHolds() {
        let note = CalibrationCoverage.note(
            for: Self.capturing(48_000), installed: nil, calibrations: Self.calibrations)
        #expect(note == nil)
    }

    @Test func noCalibrationsReadGivesNoNote() {
        #expect(
            CalibrationCoverage.note(for: Self.capturing(44_100), installed: nil, calibrations: nil)
                == nil)
    }
}
