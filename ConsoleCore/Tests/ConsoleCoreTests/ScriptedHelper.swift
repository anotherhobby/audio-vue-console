import Foundation
import Synchronization

@testable import ConsoleCore

/// What a scripted helper does with one request.
enum ScriptedReply: Sendable {
    /// Answers with `header` as JSON text, `payload` after it.
    case answer(String, payload: Data = Data())
    /// Ends, as a crashed helper does.
    case end
    /// Writes a header that is not JSON.
    case garbage
    /// Answers with `header` once the launcher's `releaseHeld()` is called.
    case held(String)
    /// Answers with `header` and `payload` once the launcher's `releaseHeld()` is called.
    case heldWith(String, payload: Data)
}

/// Starts scripted helpers, each answering by `script`, and counts the starts and the requests.
final class ScriptedLauncher: HelperLauncher {
    private let script: @Sendable (JSONValue) -> ScriptedReply
    private let counts = Mutex((launches: 0, requests: [JSONValue]()))
    private let current = Mutex<ScriptedHelper?>(nil)
    private let fails: Bool

    init(fails: Bool = false, _ script: @escaping @Sendable (JSONValue) -> ScriptedReply) {
        self.script = script
        self.fails = fails
    }

    var launches: Int { counts.withLock { $0.launches } }
    var requests: [JSONValue] { counts.withLock { $0.requests } }

    func launch() throws -> any RunningHelper {
        if fails { throw HelperLocation.Missing.interpreter }
        counts.withLock { $0.launches += 1 }
        let helper = ScriptedHelper(script: script) { request in
            self.counts.withLock { $0.requests.append(request) }
        }
        current.withLock { $0 = helper }
        return helper
    }

    /// Sends the answer the current helper is holding back.
    func releaseHeld() {
        current.withLock { $0 }?.releaseHeld()
    }
}

/// A helper that answers each request as its script says, through the same channel the real one
/// reads its output into.
final class ScriptedHelper: RunningHelper {
    private let script: @Sendable (JSONValue) -> ScriptedReply
    private let heard: @Sendable (JSONValue) -> Void
    private let output = ChunkChannel()
    private let held = Mutex<Data?>(nil)

    init(
        script: @escaping @Sendable (JSONValue) -> ScriptedReply,
        heard: @escaping @Sendable (JSONValue) -> Void
    ) {
        self.script = script
        self.heard = heard
    }

    func write(_ data: Data) throws {
        var reader = HelperAnswerReader()
        reader.append(data)
        guard let request = try reader.next()?.header else { return }
        heard(request)
        switch script(request) {
        case .answer(let header, let payload):
            output.send(HelperFrameTests.framed(header, payload: payload))
        case .end:
            output.finish()
        case .garbage:
            output.send(HelperFrameTests.framed("not json"))
        case .held(let header):
            held.withLock { $0 = HelperFrameTests.framed(header) }
        case .heldWith(let header, let payload):
            held.withLock { $0 = HelperFrameTests.framed(header, payload: payload) }
        }
    }

    func releaseHeld() {
        if let answer = held.withLock({ $0.take() }) { output.send(answer) }
    }

    func nextChunk() async -> Data? {
        await output.next()
    }

    func stop() {
        output.finish()
    }
}
