import Foundation
import Testing

@testable import ConsoleCore

/// The runs list the Calibration page binds to (`calibration-history`).
@MainActor struct CalibrationRunsTests {
    private static let kept = Pairing(hostID: "h1", token: HostToken("secret"), clientID: "me")
    private static let two = FakeTransport.Answer.status(
        200,
        #"""
        {"runs": [
          {"run_id": "2026-11-01T14-55-02Z", "has_report": true, "kind": "calibration",
           "applicable": true},
          {"run_id": "2026-10-25T23-16-08Z", "has_report": true, "kind": "calibration",
           "applicable": true}]}
        """#)

    /// The runs, an install with the rate written, and a schema declaring the default.
    private static let answers: [FakeTransport.Route: FakeTransport.Answer] = [
        .runs: two,
        .install: .status(
            200, #"{"blocks": [{"block": "input", "rev": 2, "doc": {"rate": 96000}}]}"#),
        .schema: .status(
            200,
            #"{"$defs": {"install.input": {"properties": {"rate": {"default": 48000}}}}}"#),
    ]

    private final class Unpaired {
        var times = 0
    }

    private func runs(
        _ transport: FakeTransport, tokens: InMemoryTokenStore = InMemoryTokenStore(),
        unpaired: Unpaired = Unpaired()
    ) throws -> CalibrationRuns {
        CalibrationRuns(
            address: try #require(HostAddress(parsing: "audio-vue")),
            client: HostClient(transport: transport), pairing: Self.kept, store: tokens
        ) { unpaired.times += 1 }
    }

    @Test func aLoadListsTheRunsNewestFirst() async throws {
        let model = try runs(FakeTransport(Self.answers))
        await model.load()
        #expect(model.state == .loaded)
        #expect(model.runs.map(\.id) == ["2026-11-01T14-55-02Z", "2026-10-25T23-16-08Z"])
        #expect(model.installedRate == 96_000)
    }

    @Test func aFailedLoadKeepsTheEarlierListAndTheFailure() async throws {
        let transport = FakeTransport(Self.answers)
        let model = try runs(transport)
        await model.load()
        await transport.answer(.runs, with: .failure(URLError(.timedOut)))
        await model.load()
        #expect(model.state == .failed(.unreachable))
        #expect(model.runs.count == 2)
    }

    @Test func aRefusedTokenUnpairs() async throws {
        let tokens = InMemoryTokenStore()
        let unpaired = Unpaired()
        let model = try runs(
            FakeTransport([.runs: .status(401, #"{"detail": "no"}"#)]), tokens: tokens,
            unpaired: unpaired)
        await model.load()
        #expect(model.state == .unpaired)
        #expect(unpaired.times == 1)
    }

    @Test func aReportIsFetchedWhenAsked() async throws {
        let model = try runs(
            FakeTransport([
                .report("2026-11-01T14-55-02Z"): .status(
                    200, "<html></html>", headers: ["Content-Type": "text/html"])
            ]))
        let run = RunEntry(id: "2026-11-01T14-55-02Z", hasReport: true, kind: "calibration")
        #expect(try await model.report(run) == "<html></html>")
    }
}
