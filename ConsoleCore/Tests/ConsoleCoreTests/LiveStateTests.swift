import Foundation
import Testing

@testable import ConsoleCore

/// `host-client`: the live state, a closed socket opened again, and a refused one.
@MainActor
struct LiveStateTests {
    private static let up = #"{"condition": "up", "sections": {"scene": {"name": "RTA"}}}"#
    private static let stale = #"{"condition": "stale", "sections": {"scene": {"name": "RTA"}}}"#
    private static let host = #"{"id": "h1", "name": "cabin"}"#
    private static let pairing = Pairing(hostID: "h1", token: HostToken("secret"), clientID: "c1")

    private let waits = RecordedWaits()
    private let tokens = InMemoryTokenStore()
    private let refused = Refusals()

    /// How many times the watcher said the token was refused.
    @MainActor private final class Refusals {
        var times = 0
    }

    @Test func aPushedChangeReplacesTheState() async throws {
        let events = ScriptedEvents([.init(messages: [Self.up, Self.stale], end: nil)])
        let (live, watching) = try watch(events)
        await events.settled()
        // The scripted socket stays open, so the second state is held while live.
        #expect(live.state?.condition == .stale)
        #expect(live.isLive)
        watching.cancel()
        await watching.value
    }

    @Test func aClosedSocketKeepsItsStateNotLiveThenComesBack() async throws {
        let events = ScriptedEvents([
            .init(messages: [Self.up], end: .closed), .init(messages: [], end: .closed),
        ])
        let (live, watching) = try watch(events)
        await events.settled()
        #expect(live.state?.condition == .up)
        #expect(!live.isLive)
        #expect(waits.all == [.seconds(1), .seconds(1)])
        watching.cancel()
        await watching.value
    }

    @Test func aHostThatStaysAwayIsTriedLessOftenUpToTheLimit() async throws {
        let closed = Array(repeating: ScriptedEvents.Run(messages: [], end: .closed), count: 8)
        let events = ScriptedEvents(closed)
        let (_, watching) = try watch(events)
        await events.settled()
        #expect(waits.all == [1, 2, 4, 8, 16, 30, 30, 30].map { Duration.seconds($0) })
        watching.cancel()
        await watching.value
    }

    @Test func aStateResetsTheWait() async throws {
        let events = ScriptedEvents([
            .init(messages: [], end: .closed), .init(messages: [], end: .closed),
            .init(messages: [Self.up], end: .closed),
        ])
        let (_, watching) = try watch(events)
        await events.settled()
        #expect(waits.all == [1, 2, 1].map { Duration.seconds($0) })
        watching.cancel()
        await watching.value
    }

    @Test func aRevokedTokenIsForgottenAndTheSocketNotOpenedAgain() async throws {
        let address = try #require(HostAddress(parsing: "audio-vue"))
        try tokens.save(Self.pairing, at: address)
        let events = ScriptedEvents([.init(messages: [Self.up], end: .refused)])
        let transport = FakeTransport([.host: .status(401, #"{"detail": "pair first"}"#)])
        let (live, watching) = try watch(events, transport: transport)
        await watching.value
        #expect(tokens.pairing(at: address) == nil)
        #expect(refused.times == 1)
        #expect(events.opened == 1)
        #expect(!live.isLive)
    }

    @Test func aRefusedTokenAlreadyReplacedIsNotForgotten() async throws {
        let address = try #require(HostAddress(parsing: "audio-vue"))
        let again = Pairing(hostID: "h1", token: HostToken("new"), clientID: "c2")
        try tokens.save(again, at: address)
        let events = ScriptedEvents([.init(messages: [], end: .refused)])
        let transport = FakeTransport([.host: .status(401, #"{"detail": "pair first"}"#)])
        let (_, watching) = try watch(events, transport: transport)
        await watching.value
        #expect(tokens.pairing(at: address) == again)
        #expect(refused.times == 0)
        #expect(events.opened == 1)
    }

    @Test func aRefusedSocketWhoseTokenStillWorksIsOpenedAgain() async throws {
        let events = ScriptedEvents([.init(messages: [], end: .refused)])
        let transport = FakeTransport([.host: .status(200, Self.host)])
        let (_, watching) = try watch(events, transport: transport)
        await events.settled()
        #expect(refused.times == 0)
        #expect(events.opened == 2)
        watching.cancel()
        await watching.value
    }

    @Test func aSilentSocketIsClosedAndOpenedAgain() async throws {
        let events = ScriptedEvents([.init(messages: [Self.up], end: nil)])
        let (live, watching) = try watch(events, watchdog: events.silenceAfterTheMessages)
        await events.settled()
        await events.settled()
        // The silence closed the first socket, which had given a state, so the wait stayed short.
        #expect(events.opened >= 2)
        #expect(events.cancelled >= 1)
        #expect(waits.all.first == .seconds(1))
        #expect(live.state?.condition == .up)
        watching.cancel()
        await watching.value
    }

    @Test func cancellingClosesTheSocket() async throws {
        let events = ScriptedEvents([])
        let (live, watching) = try watch(events)
        await events.settled()
        watching.cancel()
        await watching.value
        #expect(events.cancelled == 1)
        #expect(!live.isLive)
    }

    @Test func aMessageThatIsNotAStateIsSkipped() async throws {
        let events = ScriptedEvents([.init(messages: [Self.up, "not a state"], end: nil)])
        let (live, watching) = try watch(events)
        await events.settled()
        #expect(live.state?.condition == .up)
        watching.cancel()
        await watching.value
    }

    /// A live state of the host at `audio-vue` over `events`, watching in a task.
    private func watch(
        _ events: ScriptedEvents, transport: FakeTransport = FakeTransport([:]),
        watchdog: @escaping @Sendable (Duration) async -> Void = ScriptedEvents.noSilence
    ) throws -> (LiveState, Task<Void, Never>) {
        let address = try #require(HostAddress(parsing: "audio-vue"))
        let refused = refused
        let link = LiveState.Link(
            address: address, pairing: Self.pairing, client: HostClient(transport: transport),
            tokens: tokens)
        let waits = waits
        let live = LiveState(
            link, events: events, sleep: { await waits.wait($0) }, watchdog: watchdog,
            onTokenRefused: { refused.times += 1 })
        return (live, Task { await live.watch() })
    }
}
