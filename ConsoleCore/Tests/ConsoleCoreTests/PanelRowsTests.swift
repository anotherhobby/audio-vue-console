import Foundation
import Testing

@testable import ConsoleCore

/// `panel-window`: the Panel page's sections and the dash rule.
struct PanelRowsTests {
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

    private static func values(_ section: PanelRows.Section) -> [String] {
        section.rows.map(\.value)
    }

    @Test func aPairedHostWhosePanelIsUp() {
        let rows = PanelRows(
            host: Self.host, state: Self.up(), renderer: .ready(digest: "d"), cardCode: .same)
        #expect(rows.sections.map(\.title) == ["Status", "Capture", "Calibration"])
        #expect(Self.values(rows.status) == ["Up", "RTA", "1920 × 1080", "Ready"])
        #expect(Self.values(rows.capture) == ["m2x4HD", "96 kHz", "0.9 ms of a 5.3 ms budget"])
        #expect(Self.values(rows.calibration) == ["Calibrated", "12 days"])
        #expect(rows.sections.allSatisfy { $0.note == nil })
    }

    @Test(arguments: [
        (Renderer.Phase.idle, PanelRows.dash, false),
        (.starting, "Starting…", true),
        (.preparing, "Making the first frame…", true),
        (.ready(digest: "d"), "Checking the card code…", true),
    ])
    func theRenderersRowWhileStarting(phase: Renderer.Phase, value: String, working: Bool) throws {
        let row = try Self.rendererRow(phase, nil)
        #expect(row.value == value)
        #expect(row.working == working)
        #expect(!row.warning)
    }

    @Test func readyOnlyWhenTheCodeIsThePanels() throws {
        let row = try Self.rendererRow(.ready(digest: "d"), .same)
        #expect(row.value == "Ready")
        #expect(!row.warning && !row.working)
    }

    @Test func sharedCodeDifferingIsAWarningNotReady() throws {
        let drift = CardDrift.between(
            bundled: CardManifest(digest: "a", entries: ["src/frame.py": "1"]),
            host: CardManifest(digest: "b", entries: ["src/frame.py": "2"]), source: .panel)
        let row = try Self.rendererRow(.ready(digest: "d"), .differs(drift))
        #expect(row.value == "Not drawing: card code differs from the panel's. Scenes says which.")
        #expect(row.warning)
    }

    @Test func aCardDifferingIsAWarning() throws {
        let drift = CardDrift.between(
            bundled: CardManifest(
                digest: "a", entries: ["src/cards/waveform": "1"],
                cards: ["waveform": "src/cards/waveform"]),
            host: CardManifest(
                digest: "b", entries: ["src/cards/waveform": "2"],
                cards: ["waveform": "src/cards/waveform"]), source: .panel)
        let row = try Self.rendererRow(.ready(digest: "d"), .differs(drift))
        #expect(row.value == "Ready, but some cards differ from the panel's. Scenes says which.")
        #expect(row.warning)
    }

    @Test func aDamagedBundleAndAFailedStartAreWarnings() throws {
        #expect(try Self.rendererRow(.ready(digest: "d"), .damagedBundle).warning)
        let unreadable = try Self.rendererRow(.ready(digest: "d"), .unreadable)
        #expect(unreadable.value == "Not drawing: the panel's card code can't be read")
        #expect(unreadable.warning)
        let failed = try Self.rendererRow(.failed("This build carries no renderer."), nil)
        #expect(failed.value == "Could not start: This build carries no renderer.")
        #expect(failed.warning)
    }

    private static func rendererRow(_ phase: Renderer.Phase, _ code: CardCodeVerdict?) throws
        -> PanelRows.Row
    {
        let row = try #require(
            PanelRows(host: host, state: up(), renderer: phase, cardCode: code).status.rows.last)
        #expect(row.label == "Renderer")
        return row
    }

    @Test func notPairedEveryValueIsADash() {
        let rows = PanelRows(host: nil, state: nil)
        #expect(rows.sections.flatMap(\.rows).allSatisfy { $0.value == PanelRows.dash })
    }

    @Test func aPanelThatIsDown() {
        var state = PanelState(condition: .down)
        state.since = Date(timeIntervalSince1970: 0)
        let rows = PanelRows(
            host: HostIdentity(id: "h1", name: "cabin", widthPx: nil, heightPx: nil),
            state: state, time: { _ in "07:42" })
        #expect(Self.values(rows.status) == ["Down since 07:42", "—", "—", "—"])
        #expect(Self.values(rows.capture) == ["—", "—", "—"])
        #expect(Self.values(rows.calibration) == ["—", "—"])
    }

    @Test func aDownPanelWithNoTimeSaysDown() {
        #expect(
            PanelRows(host: nil, state: PanelState(condition: .down)).status.rows[0].value
                == "Down")
    }

    @Test(arguments: [
        (PanelState.Condition.stale, "Not drawing"), (.captureStopped, "Capture stopped"),
        (.noAudio, "No audio"),
    ])
    func theConditionInWords(condition: PanelState.Condition, words: String) {
        let rows = PanelRows(host: nil, state: PanelState(condition: condition))
        #expect(rows.status.rows[0].value == words)
    }

    @Test func aSectionUnavailableSaysWhy() {
        var state = Self.up()
        state.captureDevice = nil
        state.rateHz = nil
        state.unavailable = [.capture: "the device went away"]
        let rows = PanelRows(host: Self.host, state: state)
        #expect(Self.values(rows.capture) == ["—", "—", "0.9 ms of a 5.3 ms budget"])
        #expect(rows.capture.note == "Unavailable: the device went away")
        #expect(rows.status.note == nil)
    }

    @Test(arguments: [
        ("calibrated", "Calibrated"), ("stale", "Stale"), ("shifted_by_hand", "Shifted by hand"),
        ("obsolete", "Obsolete"), ("uncalibrated", "Uncalibrated"),
        ("recalibrating", "recalibrating"),
    ])
    func theCalibrationStatus(status: String, words: String) {
        var state = Self.up()
        state.calibrationStatus = status
        #expect(PanelRows(host: nil, state: state).calibration.rows[0].value == words)
    }

    @Test(arguments: [(44_100, "44.1 kHz"), (48_000, "48 kHz"), (192_000, "192 kHz")])
    func theRate(hertz: Int, text: String) {
        var state = Self.up()
        state.rateHz = hertz
        #expect(PanelRows(host: nil, state: state).capture.rows[1].value == text)
    }

    @Test func theDisplayFallsBackToTheHostsRead() {
        var state = Self.up()
        state.displayWidthPx = nil
        state.displayHeightPx = nil
        #expect(PanelRows(host: Self.host, state: state).status.rows[2].value == "1920 × 1080")
    }

    @Test func oneDay() {
        var state = Self.up()
        state.calibrationAgeDays = 1.9
        #expect(PanelRows(host: nil, state: state).calibration.rows[1].value == "1 day")
    }
}
