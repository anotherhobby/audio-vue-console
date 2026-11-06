import Foundation
import Testing

@testable import ConsoleCore

/// `panel-window`: the Overview's sections and the dash rule.
struct OverviewRowsTests {
    private static let host = HostIdentity(id: "h1", name: "cabin", widthPx: 1920, heightPx: 1080)

    private static func up() -> PanelState {
        var state = PanelState(condition: .up)
        state.sceneName = "RTA"
        state.captureDevice = "m2x4HD"
        state.rateHz = 96_000
        state.analysisP99Ms = 0.94
        state.analysisBudgetMs = 5.333
        state.calibrationStatus = "calibrated"
        state.calibrationAgeDays = 12.4
        state.displayWidthPx = 1920
        state.displayHeightPx = 1080
        return state
    }

    private static func values(_ section: OverviewRows.Section) -> [String] {
        section.rows.map(\.value)
    }

    @Test func aPairedHostWhosePanelIsUp() {
        let rows = OverviewRows(host: Self.host, state: Self.up())
        #expect(rows.sections.map(\.title) == ["Panel", "Capture", "Calibration"])
        #expect(Self.values(rows.panel) == ["Up", "RTA", "1920 × 1080"])
        #expect(Self.values(rows.capture) == ["m2x4HD", "96 kHz", "0.9 ms of a 5.3 ms budget"])
        #expect(Self.values(rows.calibration) == ["Calibrated", "12 days"])
        #expect(rows.sections.allSatisfy { $0.note == nil })
    }

    @Test func notPairedEveryValueIsADash() {
        let rows = OverviewRows(host: nil, state: nil)
        #expect(rows.sections.flatMap(\.rows).allSatisfy { $0.value == OverviewRows.dash })
    }

    @Test func aPanelThatIsDown() {
        var state = PanelState(condition: .down)
        state.since = Date(timeIntervalSince1970: 0)
        let rows = OverviewRows(
            host: HostIdentity(id: "h1", name: "cabin", widthPx: nil, heightPx: nil),
            state: state, time: { _ in "07:42" })
        #expect(Self.values(rows.panel) == ["Down since 07:42", "—", "—"])
        #expect(Self.values(rows.capture) == ["—", "—", "—"])
        #expect(Self.values(rows.calibration) == ["—", "—"])
    }

    @Test func aDownPanelWithNoTimeSaysDown() {
        #expect(
            OverviewRows(host: nil, state: PanelState(condition: .down)).panel.rows[0].value
                == "Down")
    }

    @Test(arguments: [
        (PanelState.Condition.stale, "Not drawing"), (.captureStopped, "Capture stopped"),
        (.noAudio, "No audio"),
    ])
    func theConditionInWords(condition: PanelState.Condition, words: String) {
        let rows = OverviewRows(host: nil, state: PanelState(condition: condition))
        #expect(rows.panel.rows[0].value == words)
    }

    @Test func aSectionUnavailableSaysWhy() {
        var state = Self.up()
        state.captureDevice = nil
        state.rateHz = nil
        state.unavailable = [.capture: "the device went away"]
        let rows = OverviewRows(host: Self.host, state: state)
        #expect(Self.values(rows.capture) == ["—", "—", "0.9 ms of a 5.3 ms budget"])
        #expect(rows.capture.note == "Unavailable: the device went away")
        #expect(rows.panel.note == nil)
    }

    @Test(arguments: [
        ("calibrated", "Calibrated"), ("stale", "Stale"), ("shifted_by_hand", "Shifted by hand"),
        ("obsolete", "Obsolete"), ("uncalibrated", "Uncalibrated"),
        ("recalibrating", "recalibrating"),
    ])
    func theCalibrationStatus(status: String, words: String) {
        var state = Self.up()
        state.calibrationStatus = status
        #expect(OverviewRows(host: nil, state: state).calibration.rows[0].value == words)
    }

    @Test(arguments: [(44_100, "44.1 kHz"), (48_000, "48 kHz"), (192_000, "192 kHz")])
    func theRate(hertz: Int, text: String) {
        var state = Self.up()
        state.rateHz = hertz
        #expect(OverviewRows(host: nil, state: state).capture.rows[1].value == text)
    }

    @Test func theDisplayFallsBackToTheHostsRead() {
        var state = Self.up()
        state.displayWidthPx = nil
        state.displayHeightPx = nil
        #expect(OverviewRows(host: Self.host, state: state).panel.rows[2].value == "1920 × 1080")
    }

    @Test func oneDay() {
        var state = Self.up()
        state.calibrationAgeDays = 1.9
        #expect(OverviewRows(host: nil, state: state).calibration.rows[1].value == "1 day")
    }
}

struct DisplayShapeTests {
    @Test(arguments: [
        (1920, 1080, "16:9"), (2560, 960, "8:3"), (3840, 2160, "16:9"), (1920, 720, "8:3"),
    ])
    func theShape(width: Int, height: Int, name: String) {
        #expect(DisplayShape.name(width: width, height: height) == name)
    }

    @Test func noSizeHasNoShape() {
        #expect(DisplayShape.name(width: 0, height: 1080) == nil)
    }
}
