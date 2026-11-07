import Foundation
import Testing

@testable import ConsoleCore

/// `render-helper`: requests in order, a helper that ends started again, a refusal that keeps it.
struct RenderHelperTests {
    private static let hello = #"{"ok": true, "protocol": 1, "cards": "d1"}"#

    @Test func helloGivesTheDigest() async throws {
        let launcher = ScriptedLauncher { _ in .answer(Self.hello) }
        #expect(try await RenderHelper(launcher: launcher).hello() == "d1")
        #expect(launcher.launches == 1)
    }

    @Test func prepareSendsTheAnalysisAndRate() async throws {
        let launcher = ScriptedLauncher { _ in .answer(#"{"ok": true, "runs": 1}"#) }
        try await RenderHelper(launcher: launcher).prepare(analysis: .object([:]), rate: 48000)
        #expect(launcher.requests.first?["op"] == .string("prepare"))
        #expect(launcher.requests.first?["rate"] == .integer(48000))
        #expect(launcher.requests.first?["analysis"] == .object([:]))
    }

    @Test func aRenderGivesItsLayersBytes() async throws {
        let payload = Data(repeating: 7, count: 16)
        let launcher = ScriptedLauncher { _ in
            .answer(#"{"ok": true, "layers": [{"kind": "plate", "bytes": 16}]}"#, payload: payload)
        }
        let answer = try await RenderHelper(launcher: launcher).ask(
            .object(["op": .string("render")]))
        #expect(answer.payload == payload)
    }

    @Test func anEndFailsTheRequestAndTheNextStartsAgain() async throws {
        let launcher = ScriptedLauncher { request in
            request["op"] == .string("render") ? .end : .answer(Self.hello)
        }
        let helper = RenderHelper(launcher: launcher)
        await #expect(throws: RenderFailure.ended) {
            _ = try await helper.ask(.object(["op": .string("render")]))
        }
        #expect(try await helper.hello() == "d1")
        #expect(launcher.launches == 2)
    }

    @Test func aBrokenFrameEndsTheHelper() async throws {
        let launcher = ScriptedLauncher { _ in .garbage }
        let helper = RenderHelper(launcher: launcher)
        await #expect(throws: RenderFailure.ended) { _ = try await helper.hello() }
        await #expect(throws: RenderFailure.ended) { _ = try await helper.hello() }
        #expect(launcher.launches == 2)
    }

    @Test func aRefusalKeepsTheHelper() async throws {
        let launcher = ScriptedLauncher { request in
            request["op"] == .string("render")
                ? .answer(#"{"ok": false, "refused": "names a card that does not exist"}"#)
                : .answer(Self.hello)
        }
        let helper = RenderHelper(launcher: launcher)
        await #expect(throws: RenderFailure.refused("names a card that does not exist")) {
            _ = try await helper.ask(.object(["op": .string("render")]))
        }
        #expect(try await helper.hello() == "d1")
        #expect(launcher.launches == 1)
    }

    @Test func aHelperThatCannotStart() async {
        let launcher = ScriptedLauncher(fails: true) { _ in .answer(Self.hello) }
        await #expect(
            throws: RenderFailure.unavailable(HelperLocation.Missing.interpreter.description)
        ) {
            _ = try await RenderHelper(launcher: launcher).hello()
        }
    }

    @Test func requestsAreAnsweredInTheOrderAsked() async throws {
        let launcher = ScriptedLauncher { request in
            .answer(#"{"ok": true, "cards": "\#(request["n"]?.intValue ?? -1)"}"#)
        }
        let helper = RenderHelper(launcher: launcher)
        async let first = helper.ask(.object(["op": .string("hello"), "n": .integer(1)]))
        async let second = helper.ask(.object(["op": .string("hello"), "n": .integer(2)]))
        let answers = try await [first, second]
        #expect(answers.map { $0.header["cards"] } == [.string("1"), .string("2")])
    }
}
