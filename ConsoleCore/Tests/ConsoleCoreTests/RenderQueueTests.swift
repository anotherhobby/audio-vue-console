import Foundation
import Testing

@testable import ConsoleCore

/// Design D3: one request at a time, the canvas first, a newer canvas request replacing one unsent.
@MainActor
struct RenderQueueTests {
    private static func message(_ number: Int) -> JSONValue {
        .object(["op": .string("render"), "n": .integer(number)])
    }

    /// Waits, briefly, for `condition` to hold.
    private static func until(_ condition: () -> Bool) async throws {
        for _ in 0..<200 where !condition() {
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func theCanvasGoesFirstAndANewerRequestReplacesOneUnsent() async throws {
        let launcher = ScriptedLauncher { request in
            let number = request["n"]?.intValue ?? 0
            let answer = #"{"ok": true, "n": \#(number)}"#
            return number == 1 ? .held(answer) : .answer(answer)
        }
        let queue = RenderQueue(helper: RenderHelper(launcher: launcher))
        let first = Task { await queue.submit(Self.message(1), lane: .canvas, key: "a") }
        try await Self.until { launcher.requests.count == 1 }

        let replaced = Task { await queue.submit(Self.message(2), lane: .canvas, key: "k") }
        try await Self.until { queue.waiting == 1 }
        let newer = Task { await queue.submit(Self.message(3), lane: .canvas, key: "k") }
        let thumbnail = Task { await queue.submit(Self.message(4), lane: .thumbnails, key: "t") }
        let canvas = Task { await queue.submit(Self.message(5), lane: .canvas, key: "e") }
        try await Self.until { queue.waiting == 3 }
        #expect(await replaced.value == nil)

        launcher.releaseHeld()
        for task in [first, newer, thumbnail, canvas] {
            #expect(try await task.value?.get().header["ok"] == .bool(true))
        }
        #expect(launcher.requests.map { $0["n"]?.intValue } == [1, 3, 5, 4])
    }

    /// `library-render` design D2: the library's lane goes after the canvas's and before the
    /// thumbnails', and replaces by key within its own lane alone.
    @Test func theLibraryGoesBetweenTheCanvasAndTheThumbnails() async throws {
        let launcher = ScriptedLauncher { request in
            let number = request["n"]?.intValue ?? 0
            let answer = #"{"ok": true, "n": \#(number)}"#
            return number == 1 ? .held(answer) : .answer(answer)
        }
        let queue = RenderQueue(helper: RenderHelper(launcher: launcher))
        let first = Task { await queue.submit(Self.message(1), lane: .canvas, key: "a") }
        try await Self.until { launcher.requests.count == 1 }

        let thumbnail = Task { await queue.submit(Self.message(2), lane: .thumbnails, key: "k") }
        try await Self.until { queue.waiting == 1 }
        let replaced = Task { await queue.submit(Self.message(3), lane: .library, key: "k") }
        try await Self.until { queue.waiting == 2 }
        let newer = Task { await queue.submit(Self.message(4), lane: .library, key: "k") }
        try await Self.until { queue.waiting == 2 }
        #expect(await replaced.value == nil)
        let canvas = Task { await queue.submit(Self.message(5), lane: .canvas, key: "k") }
        try await Self.until { queue.waiting == 3 }

        launcher.releaseHeld()
        for task in [first, thumbnail, newer, canvas] {
            #expect(try await task.value?.get().header["ok"] == .bool(true))
        }
        #expect(launcher.requests.map { $0["n"]?.intValue } == [1, 5, 4, 2])
    }

    @Test func aFailureIsAnswered() async throws {
        let launcher = ScriptedLauncher { _ in .end }
        let queue = RenderQueue(helper: RenderHelper(launcher: launcher))
        let result = await queue.submit(Self.message(1), lane: .canvas, key: "a")
        #expect(throws: RenderFailure.ended) { try result?.get() }
    }
}
