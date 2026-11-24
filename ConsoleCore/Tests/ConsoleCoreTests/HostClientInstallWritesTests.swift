import Foundation
import Testing

@testable import ConsoleCore

/// Design D2: an install write sends the block's document on its base revision with the token, and
/// each refusal comes back as the failure the host names.
struct HostClientInstallWritesTests {
    private let token = HostToken("secret")
    private let doc: [String: JSONValue] = [
        "rate": .integer(96_000), "pair": .array([.integer(2), .integer(3)]),
    ]

    private func address() throws -> HostAddress {
        try #require(HostAddress(parsing: "audio-vue"))
    }

    private func write(over transport: FakeTransport) async throws -> InstallWritten {
        try await HostClient(transport: transport).writeInstall(
            doc, block: "input", base: 4, at: try address(), token: token)
    }

    @Test func aWriteSendsTheDocumentOnItsBase() async throws {
        let answer =
            #"{"block": "input", "rev": 5, "applies": "restarted", "chain_changed": ["rate"], "#
            + #""calibration": "the panel's 96 kHz is uncalibrated"}"#
        let transport = FakeTransport([.writeInstall("input"): .status(200, answer)])
        let written = try await write(over: transport)
        #expect(written.rev == 5 && written.applies == .restarted)
        #expect(written.chainChanged == ["rate"])
        #expect(written.calibration == "the panel's 96 kHz is uncalibrated")
        let request = try #require(await transport.requests.first)
        let body = try JSONDecoder().decode(JSONValue.self, from: try #require(request.httpBody))
        #expect(body == .object(["doc": .object(doc), "base_rev": .integer(4)]))
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    /// A chain write is answered only once the panel has restarted, so it goes through the
    /// transport that waits for that, and every other call does not.
    @Test func aWriteWaitsForTheRestart() async throws {
        let answer = #"{"block": "input", "rev": 5, "applies": "restarted"}"#
        let quick = FakeTransport([:])
        let patient = FakeTransport([.writeInstall("input"): .status(200, answer)])
        _ = try await HostClient(transport: quick, restartTransport: patient).writeInstall(
            doc, block: "input", base: 4, at: try address(), token: token)
        #expect(await patient.requests.count == 1)
        #expect(await quick.requests.isEmpty)
    }

    @Test func aWriteThatChangesNoChainSaysNothingOfCalibration() async throws {
        let answer = #"{"block": "input", "rev": 5, "applies": "on_restart"}"#
        let transport = FakeTransport([.writeInstall("input"): .status(200, answer)])
        let written = try await write(over: transport)
        #expect(written.chainChanged.isEmpty && written.calibration == nil)
    }

    /// `track-native-logo` design D3: a `display` write applies at the panel's next start.
    @Test func aDisplayWriteAppliesAtTheNextStart() async throws {
        let answer = #"{"block": "display", "rev": 3, "applies": "on_start"}"#
        let transport = FakeTransport([.writeInstall("display"): .status(200, answer)])
        let written = try await HostClient(transport: transport).writeInstall(
            ["saver_after_min": .integer(10)], block: "display", base: 2, at: try address(),
            token: token)
        #expect(written.rev == 3 && written.applies == .onStart)
    }

    @Test func aStaleWriteSaysTheCurrentRevision() async throws {
        let answer = #"{"detail": "the block has moved on", "current_rev": 6}"#
        let transport = FakeTransport([.writeInstall("input"): .status(409, answer)])
        await #expect(throws: HostFailure.stale(currentRev: 6)) {
            _ = try await write(over: transport)
        }
    }

    @Test func anInvalidWriteNamesItsFailure() async throws {
        let answer =
            #"{"detail": "invalid", "failures": [{"place": "rate", "message": "below 1"}]}"#
        let transport = FakeTransport([.writeInstall("input"): .status(422, answer)])
        let failure = DocumentFailure(place: "rate", message: "below 1")
        await #expect(throws: HostFailure.invalid([failure])) {
            _ = try await write(over: transport)
        }
    }

    /// The refusal during a calibration carries no revision, only the host's words (alignment F2).
    @Test func theRefusalDuringACalibrationSaysWhy() async throws {
        let words = "a calibration has the panel -- cancel it first"
        let transport = FakeTransport([
            .writeInstall("input"): .status(409, #"{"detail": "\#(words)"}"#)
        ])
        await #expect(throws: HostFailure.conflict(words)) {
            _ = try await write(over: transport)
        }
    }
}
