import Foundation
import Observation

/// The panel's state as the host pushes it on `/v1/events`, for one paired host (`host-client`,
/// "The app keeps the panel's live state"; design D6). `watch()` runs the socket until cancelled:
/// the window runs it in a `.task`, so the socket is open while the window shows the host. A socket
/// silent for `silence` is closed and opened again, since the host pushes the whole state every
/// second.
@MainActor @Observable
public final class LiveState {
    /// The newest state the host pushed, kept after the socket closes.
    public private(set) var state: PanelState?
    /// Whether `state` is current: a socket is open and has given a state since it opened.
    public private(set) var isLive = false

    /// The wait before the first reopening, doubled after each one that fails, up to `longestWait`.
    static let firstWait = Duration.seconds(1)
    static let longestWait = Duration.seconds(longestWaitSeconds)
    private static let longestWaitSeconds: Int64 = 30
    /// How long a socket may go without a message before it counts as closed: five of the host's
    /// whole-state pushes, a second apart.
    static let silence = Duration.seconds(silenceSeconds)
    private static let silenceSeconds: Int64 = 5

    private let address: HostAddress
    private let pairing: Pairing
    private let client: HostClient
    private let tokens: any TokenStore
    private let events: any EventSource
    private let sleep: @Sendable (Duration) async -> Void
    private let watchdog: @Sendable (Duration) async -> Void
    private let onTokenRefused: () -> Void
    /// The messages the open socket has given, which the watchdog reads to tell silence.
    private var messagesSeen = 0
    private var socketGaveState = false

    /// The live state of the host at `address`, paired as `pairing`, calling `onTokenRefused` once
    /// the host no longer takes the token, which it forgets first.
    public convenience init(
        address: HostAddress, pairing: Pairing, tokens: any TokenStore,
        onTokenRefused: @escaping () -> Void
    ) {
        self.init(
            Link(address: address, pairing: pairing, client: HostClient(), tokens: tokens),
            events: WebSocketEventSource(), sleep: Self.taskSleep, watchdog: Self.taskSleep,
            onTokenRefused: onTokenRefused)
    }

    /// The host this follows, and how to reach it.
    struct Link {
        let address: HostAddress
        let pairing: Pairing
        let client: HostClient
        let tokens: any TokenStore
    }

    /// `sleep` waits before a reopening, and `watchdog` times a silence; tests pass their own.
    init(
        _ link: Link, events: any EventSource, sleep: @escaping @Sendable (Duration) async -> Void,
        watchdog: @escaping @Sendable (Duration) async -> Void, onTokenRefused: @escaping () -> Void
    ) {
        address = link.address
        pairing = link.pairing
        client = link.client
        tokens = link.tokens
        self.events = events
        self.sleep = sleep
        self.watchdog = watchdog
        self.onTokenRefused = onTokenRefused
    }

    /// Opens the socket and holds each state it gives, opening it again after a close, until the
    /// task is cancelled or the host refuses the token.
    public func watch() async {
        var wait = Self.firstWait
        while !Task.isCancelled {
            let end = await follow()
            isLive = false
            if end == .refused, await endsOnRefusal() { return }
            if end == .gaveState { wait = Self.firstWait }
            guard !Task.isCancelled else { return }
            await sleep(wait)
            wait = Self.wait(after: wait, ended: end)
        }
    }

    private enum End {
        case gaveState, closed, refused
    }

    /// The wait before the next reopening: doubled up to `longestWait` after a socket that gave no
    /// state, and kept after one that did, which `watch` has already reset.
    private static func wait(after wait: Duration, ended end: End) -> Duration {
        end == .gaveState ? wait : min(wait * 2, longestWait)
    }

    /// Whether a refused handshake ends the watch: it does when the host refuses the token on a
    /// request too, saying so where the token was the one kept.
    private func endsOnRefusal() async -> Bool {
        guard let refusal = await refusal() else { return false }
        if refusal == .forgotten { onTokenRefused() }
        return true
    }

    /// One socket, from opening to its end: its close, or a silence the watchdog times. Whichever
    /// comes first ends it, and the other is cancelled, which closes the socket.
    private func follow() async -> End {
        messagesSeen = 0
        socketGaveState = false
        return await withTaskGroup(of: End.self) { group in
            group.addTask { await self.read() }
            group.addTask { await self.silenceEnds() }
            let end = await group.next() ?? .closed
            group.cancelAll()
            return end
        }
    }

    /// Holds each state the socket gives, until it ends.
    private func read() async -> End {
        do {
            for try await message in events.messages(at: address, token: pairing.token) {
                messagesSeen += 1
                guard let next = Self.state(from: message) else { continue }
                state = next
                isLive = true
                socketGaveState = true
            }
        } catch EventsEnd.refused {
            return .refused
        } catch {
            return socketGaveState ? .gaveState : .closed
        }
        return socketGaveState ? .gaveState : .closed
    }

    /// Returns once a whole `silence` passes with no message, or when cancelled.
    private func silenceEnds() async -> End {
        var seen = -1
        while seen != messagesSeen, !Task.isCancelled {
            seen = messagesSeen
            await watchdog(Self.silence)
        }
        return socketGaveState ? .gaveState : .closed
    }

    /// A message's state, or nil for one that is not a state, which is skipped.
    private static func state(from message: Data) -> PanelState? {
        do {
            return try PanelState(json: message)
        } catch {
            return nil
        }
    }

    private enum Refusal {
        /// The token was the one kept, and is forgotten.
        case forgotten
        /// The app has paired again since, so the token kept is another, and stays.
        case replaced
    }

    /// Whether the host refuses the token on a request too, since a refused handshake may be an
    /// `Origin` refusal rather than the token's (design D6), or nil where it takes it. A refused
    /// token is forgotten only while it is still the one kept, so pairing again is not undone.
    private func refusal() async -> Refusal? {
        do {
            _ = try await client.host(at: address, token: pairing.token)
            return nil
        } catch {
            guard error == .tokenRefused else { return nil }
            guard tokens.pairing(forHost: pairing.hostID)?.token == pairing.token else {
                return .replaced
            }
            tokens.forget(host: pairing.hostID)
            return .forgotten
        }
    }

    private static let taskSleep: @Sendable (Duration) async -> Void = { duration in
        do {
            try await Task.sleep(for: duration)
        } catch {
            return
        }
    }
}
