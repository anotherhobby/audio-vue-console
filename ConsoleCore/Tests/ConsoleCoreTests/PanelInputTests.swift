import Foundation
import Testing

@testable import ConsoleCore

/// The Capture page's Input section's model (`capture-input`, design D2).
@MainActor struct PanelInputTests {
    private static let kept = Pairing(hostID: "h1", token: HostToken("secret"), clientID: "me")
    private static let d10s = "hw:CARD=D10s,DEV=0"

    private static let schema = FakeTransport.Answer.status(
        200,
        #"{"$defs": {"install.input": {"properties": {"rate": "#
            + #"{"default": 48000, "enum": [44100, 48000, 88200, 96000, 192000]}, "#
            + #""fmt": {"default": "S16_LE", "enum": ["S16_LE", "S32_LE"]}}}}}"#)
    private static let devices = FakeTransport.Answer.status(
        200, #"{"devices": ["\#(d10s)", "hw:CARD=Device,DEV=0"]}"#)

    private static func install(_ input: String) -> FakeTransport.Answer {
        .status(200, #"{"blocks": [\#(input)]}"#)
    }

    private static let written = FakeTransport.Answer.status(
        200,
        #"{"block": "input", "rev": 5, "applies": "restarted", "chain_changed": ["rate"], "#
            + #""calibration": "96 kHz holds no calibration"}"#)

    /// Valid calibrations at 48 and 96 kHz, the second stale.
    private static let calibrated = FakeTransport.Answer.status(
        200,
        #"{"rates": [{"rate": 48000, "run_id": "r1", "status": "calibrated"},"#
            + #"{"rate": 96000, "run_id": "r2", "status": "stale"}]}"#)

    private static func answers(input: String) -> [FakeTransport.Route: FakeTransport.Answer] {
        [.install: install(input), .schema: schema, .devices: devices, .calibrated: calibrated]
    }

    private func model(_ transport: FakeTransport) throws -> PanelInput {
        PanelInput(
            address: try #require(HostAddress(parsing: "audio-vue")),
            client: HostClient(transport: transport), pairing: Self.kept,
            store: InMemoryTokenStore()
        ) {}
    }

    @Test func aBlockNeverWrittenShowsTheDefaults() async throws {
        let input = try model(
            FakeTransport(Self.answers(input: #"{"block": "input", "rev": 0, "doc": {}}"#)))
        await input.load()
        #expect(input.state == .loaded)
        #expect(input.device == nil && input.rate == 48_000)
        #expect(input.rates == [44_100, 48_000, 88_200, 96_000, 192_000])
        #expect(input.devices.count == 2 && input.isDeviceAttached)
        #expect(input.format == "S16_LE" && input.formats == ["S16_LE", "S32_LE"])
        #expect(input.isFormatOffered)
    }

    @Test func anInstalledFormatTheHostDoesNotOfferShowsAsItIs() async throws {
        let block = #"{"block": "input", "rev": 2, "doc": {"fmt": "S24_3LE"}}"#
        let input = try model(FakeTransport(Self.answers(input: block)))
        await input.load()
        #expect(!input.isFormatOffered)
        #expect(input.formatChoices == ["S16_LE", "S32_LE", "S24_3LE"])
    }

    @Test func anInstalledDeviceTheHostDoesNotListIsNotAttached() async throws {
        let block = #"{"block": "input", "rev": 2, "doc": {"device": "hw:CARD=Gone,DEV=0"}}"#
        let input = try model(FakeTransport(Self.answers(input: block)))
        await input.load()
        #expect(input.device == "hw:CARD=Gone,DEV=0")
        #expect(!input.isDeviceAttached)
    }

    /// `capture-input`, "Calibrated at two rates".
    @Test func eachRateSaysWhetherACalibrationHolds() async throws {
        let input = try model(
            FakeTransport(Self.answers(input: #"{"block": "input", "rev": 0, "doc": {}}"#)))
        await input.load()
        #expect(input.calibrations == [48_000: .calibrated, 96_000: .stale])
    }

    @Test func anUnreadableReportMarksNoRate() async throws {
        var answers = Self.answers(input: #"{"block": "input", "rev": 0, "doc": {}}"#)
        answers[.calibrated] = .status(500, "")
        let input = try model(FakeTransport(answers))
        await input.load()
        #expect(input.state == .loaded)
        #expect(input.calibrations == nil)
    }

    /// `capture-input`, "Another device chosen".
    @Test func aNewDeviceIsReadAgainForItsCalibrations() async throws {
        var answers = Self.answers(input: #"{"block": "input", "rev": 0, "doc": {}}"#)
        answers[.writeInstall("input")] = Self.written
        let transport = FakeTransport(answers)
        let input = try model(transport)
        await input.load()
        await transport.answer(.calibrated, with: .status(200, #"{"rates": []}"#))
        await input.write(device: Self.d10s, rate: 48_000, format: nil)
        #expect(input.calibrations == [:])
    }

    @Test func anInstalledRateTheHostDoesNotOfferShowsAsItIs() async throws {
        let block = #"{"block": "input", "rev": 2, "doc": {"rate": 32000}}"#
        let input = try model(FakeTransport(Self.answers(input: block)))
        await input.load()
        #expect(!input.isRateOffered)
        #expect(input.rateChoices == [32_000, 44_100, 48_000, 88_200, 96_000, 192_000])
    }

    @Test func aWriteIsMadeOnTheRevisionReadAndKeepsTheBlocksOtherKeys() async throws {
        let block = #"{"block": "input", "rev": 4, "doc": {"pair": [2, 3], "rate": 48000}}"#
        var answers = Self.answers(input: block)
        answers[.writeInstall("input")] = Self.written
        let transport = FakeTransport(answers)
        let input = try model(transport)
        await input.load()
        #expect(await input.write(device: Self.d10s, rate: 96_000, format: "S32_LE"))
        let request = try #require(await transport.requests(to: .writeInstall("input")).first)
        let body = try JSONDecoder().decode(JSONValue.self, from: try #require(request.httpBody))
        #expect(body["base_rev"] == .integer(4))
        #expect(body["doc"]?["pair"] == .array([.integer(2), .integer(3)]))
        #expect(body["doc"]?["device"] == .string(Self.d10s))
        #expect(body["doc"]?["fmt"] == .string("S32_LE"))
        #expect(input.format == "S32_LE")
        #expect(input.rate == 96_000 && input.device == Self.d10s)
        #expect(input.note == .written(calibration: "96 kHz holds no calibration"))
    }

    @Test func aStaleWriteReloadsAndSaysTheValuesChangedElsewhere() async throws {
        let block = #"{"block": "input", "rev": 4, "doc": {"rate": 48000}}"#
        var answers = Self.answers(input: block)
        answers[.writeInstall("input")] = .status(409, #"{"detail": "moved", "current_rev": 5}"#)
        let transport = FakeTransport(answers)
        let input = try model(transport)
        await input.load()
        await transport.answer(
            .install, with: Self.install(#"{"block": "input", "rev": 5, "doc": {"rate": 88200}}"#))
        #expect(!(await input.write(device: nil, rate: 96_000, format: nil)))
        #expect(input.note == .changedElsewhere)
        #expect(input.rate == 88_200)
        #expect(await transport.requests(to: .install).count == 2)
    }

    /// A write the host did not answer may still have been stored, so the block is read again.
    @Test func anUnansweredWriteShowsWhatTheHostHolds() async throws {
        var answers = Self.answers(input: #"{"block": "input", "rev": 4, "doc": {}}"#)
        answers[.writeInstall("input")] = .failure(URLError(.timedOut))
        let transport = FakeTransport(answers)
        let input = try model(transport)
        await input.load()
        await transport.answer(
            .install, with: Self.install(#"{"block": "input", "rev": 5, "doc": {"rate": 96000}}"#))
        #expect(await input.write(device: nil, rate: 96_000, format: nil))
        #expect(input.note == .unanswered)
        #expect(input.rate == 96_000)
    }

    /// `mac-output` design D1: an unanswered write the host did not store is not followed.
    @Test func anUnansweredWriteTheHostDidNotStoreIsNotHeld() async throws {
        var answers = Self.answers(input: #"{"block": "input", "rev": 4, "doc": {}}"#)
        answers[.writeInstall("input")] = .failure(URLError(.timedOut))
        let input = try model(FakeTransport(answers))
        await input.load()
        #expect(!(await input.write(device: nil, rate: 96_000, format: nil)))
        #expect(input.note == .unanswered)
        #expect(input.rate == 48_000)
    }

    /// `capture-input`, "Returning to the scene": one cancel, which ends the hold.
    @Test func returnToSceneSendsOneCancel() async throws {
        var answers = Self.answers(input: #"{"block": "input", "rev": 4, "doc": {}}"#)
        answers[.cancel] = .status(200, #"{"status": "done", "record_stands": true}"#)
        let transport = FakeTransport(answers)
        let input = try model(transport)
        await input.load()
        await input.endHold()
        #expect(await transport.requests(to: .cancel).count == 1)
        #expect(input.note == nil)
    }

    @Test func aRefusedReturnShowsThePanelsWords() async throws {
        var answers = Self.answers(input: #"{"block": "input", "rev": 4, "doc": {}}"#)
        answers[.cancel] = .status(409, #"{"status": "refused", "reason": "nothing to cancel"}"#)
        let input = try model(FakeTransport(answers))
        await input.load()
        await input.endHold()
        #expect(input.note == .refused("nothing to cancel"))
    }

    /// `capture-input`, "Refused by the host": its reason, and the installed values.
    @Test func aRefusalShowsTheHostsReasonAndTheInstalledValues() async throws {
        let words = "a calibration has the panel -- cancel it first"
        var answers = Self.answers(input: #"{"block": "input", "rev": 4, "doc": {}}"#)
        answers[.writeInstall("input")] = .status(409, #"{"detail": "\#(words)"}"#)
        let input = try model(FakeTransport(answers))
        await input.load()
        #expect(!(await input.write(device: nil, rate: 96_000, format: nil)))
        #expect(input.note == .refused(words))
        #expect(input.rate == 48_000)
    }
}
