import Foundation
import Testing

@testable import ConsoleCore

/// Design D8 and D11: a switch and a reset, each with the token, and each outcome by its status.
struct HostClientCommandsTests {
    private let token = HostToken("secret")

    private func address() throws -> HostAddress {
        try #require(HostAddress(parsing: "audio-vue"))
    }

    private func switched(_ answer: FakeTransport.Answer) async throws -> CommandOutcome {
        let transport = FakeTransport([.switchScene: answer])
        return try await HostClient(transport: transport).switchScene(
            "u1", at: try address(), token: token)
    }

    @Test func aSwitchNamesTheSceneWithTheToken() async throws {
        let transport = FakeTransport([.switchScene: .status(200, #"{"status": "done"}"#)])
        _ = try await HostClient(transport: transport).switchScene(
            "u1", at: try address(), token: token)
        let request = try #require(await transport.requests.first)
        #expect(FakeTransport.json(of: request) == ["scene": "u1"])
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
    }

    @Test func aSwitchThatKeptCapture() async throws {
        let body =
            #"{"status": "done", "scene": "u1", "capture": "kept", "why": null, "recorded": true}"#
        let outcome = try await switched(.status(200, body))
        #expect(outcome == .done(SwitchResult(capture: .kept, why: nil, recorded: true)))
    }

    @Test func aSwitchThatRebuiltCapture() async throws {
        let body =
            #"{"status": "done", "scene": "u1", "capture": "rebuilt", "#
            + #""why": "a card wants 60 s of history", "recorded": true}"#
        let outcome = try await switched(.status(200, body))
        let result = SwitchResult(
            capture: .rebuilt, why: "a card wants 60 s of history", recorded: true)
        #expect(outcome == .done(result))
    }

    @Test func aSwitchNotRecorded() async throws {
        let body =
            #"{"status": "done", "scene": "u1", "capture": "kept", "why": null, "recorded": false}"#
        let outcome = try await switched(.status(200, body))
        #expect(outcome == .done(SwitchResult(capture: .kept, why: nil, recorded: false)))
    }

    @Test(arguments: [
        (
            409, #"{"status": "refused", "reason": "a calibration has the panel"}"#,
            CommandOutcome.refused("a calibration has the panel")
        ),
        (503, #"{"status": "no panel", "reason": "the panel is not running"}"#, .noPanel),
        (
            504, #"{"status": "expired", "reason": "no answer in time"}"#,
            .expired("no answer in time")
        ),
        (504, #"{"status": "unknown", "reason": "lost"}"#, .unknown("lost")),
    ])
    func eachStatusIsItsOutcome(code: Int, body: String, outcome: CommandOutcome) async throws {
        #expect(try await switched(.status(code, body)) == outcome)
    }

    @Test func aResetIsDone() async throws {
        let transport = FakeTransport([.reset: .status(200, #"{"status": "done"}"#)])
        let outcome = try await HostClient(transport: transport).resetPanel(
            at: try address(), token: token)
        #expect(outcome == .done(nil))
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func aRefusedReset() async throws {
        let body = #"{"status": "refused", "reason": "a calibration has the panel"}"#
        let transport = FakeTransport([.reset: .status(409, body)])
        let outcome = try await HostClient(transport: transport).resetPanel(
            at: try address(), token: token)
        #expect(outcome == .refused("a calibration has the panel"))
    }

    @Test func aResetWithNoPanel() async throws {
        let body = #"{"status": "no panel", "reason": "the panel is not running"}"#
        let transport = FakeTransport([.reset: .status(503, body)])
        let outcome = try await HostClient(transport: transport).resetPanel(
            at: try address(), token: token)
        #expect(outcome == .noPanel)
    }
}
