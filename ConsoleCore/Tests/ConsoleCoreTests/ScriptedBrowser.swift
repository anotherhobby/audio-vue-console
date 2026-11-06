import Foundation
import Synchronization

@testable import ConsoleCore

/// A browser the test drives: each `updates()` call is one browse, which `send` speaks for until
/// the next starts, and each resolve answers from `answers`, unreachable where it names none.
/// `browseStarted()` returns once a browse has started that the test has not yet waited for.
final class ScriptedBrowser: ServiceBrowser {
    private struct Script {
        var answers: [String: Result<HostAddress, HostFailure>] = [:]
        var resolved: [String: Int] = [:]
        var browse: AsyncStream<BrowseUpdate>.Continuation?
        var browses = 0
    }

    private let script = Mutex(Script())
    private let started: AsyncStream<Void>
    private let startSignal: AsyncStream<Void>.Continuation

    init(answers: [String: Result<HostAddress, HostFailure>] = [:]) {
        (started, startSignal) = AsyncStream.makeStream()
        script.withLock { $0.answers = answers }
    }

    /// How many browses have started.
    var browses: Int { script.withLock(\.browses) }

    /// How many times the instance named `name` was resolved.
    func resolveCount(_ name: String) -> Int {
        script.withLock { $0.resolved[name, default: 0] }
    }

    func answer(_ name: String, with result: Result<HostAddress, HostFailure>) {
        script.withLock { $0.answers[name] = result }
    }

    /// Speaks for the browse started last.
    func send(_ update: BrowseUpdate) {
        _ = script.withLock { $0.browse?.yield(update) }
    }

    func browseStarted() async {
        for await _ in started { return }
    }

    func updates() -> AsyncStream<BrowseUpdate> {
        let (stream, continuation) = AsyncStream<BrowseUpdate>.makeStream()
        script.withLock {
            $0.browse = continuation
            $0.browses += 1
        }
        startSignal.yield()
        return stream
    }

    func resolve(_ instance: ServiceInstance) async throws(HostFailure) -> HostAddress {
        let answer = script.withLock {
            $0.resolved[instance.name, default: 0] += 1
            return $0.answers[instance.name] ?? .failure(.unreachable)
        }
        return try answer.get()
    }
}
