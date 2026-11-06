import Foundation
import Synchronization

@testable import ConsoleCore

/// An events source that plays one scripted run per socket opened: its messages, then its end.
/// Past the script, a socket stays open with nothing to say. Messages are handed out as the watcher
/// asks for them, so once it asks an open socket for one more than it has, it has read them all:
/// `settled()` returns then, and the socket waits until the watcher is cancelled.
final class ScriptedEvents: EventSource {
    struct Run: Sendable {
        let messages: [String]
        /// How the socket ends after its messages; nil leaves it open until cancelled.
        let end: EventsEnd?
    }

    private struct Script {
        var runs: [Run]
        var opened = 0
        var cancelled = 0
    }

    /// One socket's messages not yet read.
    private final class Pending: Sendable {
        let messages: Mutex<[String]>

        init(_ messages: [String]) {
            self.messages = Mutex(messages)
        }

        func next() -> String? {
            messages.withLock { $0.isEmpty ? nil : $0.removeFirst() }
        }
    }

    private let script: Mutex<Script>
    private let settledSignal: AsyncStream<Void>
    private let signal: AsyncStream<Void>.Continuation

    init(_ runs: [Run]) {
        script = Mutex(Script(runs: runs))
        (settledSignal, signal) = AsyncStream.makeStream()
    }

    /// Returns once the watcher has read every message of a socket that stays open.
    func settled() async {
        for await _ in settledSignal { return }
    }

    var opened: Int { script.withLock { $0.opened } }
    var cancelled: Int { script.withLock { $0.cancelled } }

    func messages(at address: HostAddress, token: HostToken)
        -> AsyncThrowingStream<Data, any Error>
    {
        let run = script.withLock { script -> Run? in
            script.opened += 1
            return script.runs.isEmpty ? nil : script.runs.removeFirst()
        }
        let pending = Pending(run?.messages ?? [])
        let end = run?.end
        return AsyncThrowingStream { [self] in
            if let message = pending.next() { return Data(message.utf8) }
            if let end { throw end }
            signal.yield()
            await waitUntilCancelled()
            return nil
        }
    }

    private func waitUntilCancelled() async {
        let aLongTime = Duration.seconds(3600)
        do {
            try await Task.sleep(for: aLongTime)
        } catch {
            script.withLock { $0.cancelled += 1 }
        }
    }
}

/// The waits a watcher asked for, which return at once.
final class RecordedWaits: Sendable {
    private let waits = Mutex<[Duration]>([])

    var all: [Duration] { waits.withLock { $0 } }

    func wait(_ duration: Duration) async {
        waits.withLock { $0.append(duration) }
    }
}
