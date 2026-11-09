import Foundation
import Synchronization
import Testing

@testable import ConsoleCore

/// A `cal-play` that exits as scripted, or, held, waits until stopped, exiting `stopDelay` after
/// a stop as a real process does, or at once.
final class ScriptedPlayer: RunningPlayer {
    private let stopDelay: Duration?
    private let state = Mutex<(exit: PlayerExit?, waiter: CheckedContinuation<PlayerExit, Never>?)>(
        (nil, nil))
    private let stops = Mutex(0)

    init(exit: PlayerExit?, stopDelay: Duration? = nil) {
        self.stopDelay = stopDelay
        state.withLock { $0.exit = exit }
    }

    var stopCount: Int { stops.withLock { $0 } }

    func wait() async -> PlayerExit {
        await withCheckedContinuation { continuation in
            let exit = state.withLock { state -> PlayerExit? in
                if let exit = state.exit { return exit }
                state.waiter = continuation
                return nil
            }
            if let exit { continuation.resume(returning: exit) }
        }
    }

    func stop() {
        stops.withLock { $0 += 1 }
        let stopped = PlayerExit(status: 15, errorOutput: "")
        guard let stopDelay else { return end(stopped) }
        Task {
            do {
                try await Task.sleep(for: stopDelay)
            } catch {
                // Cancelled: the player exits now rather than after the delay.
            }
            end(stopped)
        }
    }

    /// Ends a held player as `exit` says.
    func end(_ exit: PlayerExit) {
        let waiter = state.withLock { state -> CheckedContinuation<PlayerExit, Never>? in
            state.exit = exit
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume(returning: exit)
    }

    var isWaiting: Bool { state.withLock { $0.waiter != nil } }
}

/// Starts scripted players, recording each call's arguments. A call the script answers nil for is
/// held until stopped or ended.
final class ScriptedPlayerLauncher: PlayerLauncher {
    private let script: @Sendable ([String]) -> PlayerExit?
    private let stopDelay: Duration?
    private let launched = Mutex<[(arguments: [String], player: ScriptedPlayer)]>([])

    init(exit: PlayerExit?) {
        script = { _ in exit }
        stopDelay = nil
    }

    init(
        stopDelay: Duration? = nil, _ script: @escaping @Sendable ([String]) -> PlayerExit?
    ) {
        self.script = script
        self.stopDelay = stopDelay
    }

    var calls: [[String]] { launched.withLock { $0.map(\.arguments) } }
    var players: [ScriptedPlayer] { launched.withLock { $0.map(\.player) } }

    func launch(_ arguments: [String]) throws -> any RunningPlayer {
        let player = ScriptedPlayer(exit: script(arguments), stopDelay: stopDelay)
        launched.withLock { $0.append((arguments, player)) }
        return player
    }
}

@Suite struct CalibrationPlayerTests {
    private static let done = PlayerExit(status: 0, errorOutput: "D10s: 48000 -> 96000 Hz\n")

    /// A run the panel ended just before its file played cancels the play, which then starts no
    /// `cal-play` at all.
    @Test func aCancelledCallStartsNothing() async throws {
        let launcher = ScriptedPlayerLauncher(exit: Self.done)
        let player = CalibrationPlayer(launcher: launcher)
        let file = URL(filePath: "/tmp/stimulus.wav")
        let playing = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await player.play(device: "D10s ", file: file)
        }
        await #expect(throws: PlayerFailure.cancelled) { try await playing.value }
        #expect(launcher.calls.isEmpty)
    }

    @Test func setRateAndPlayPassTheirArguments() async throws {
        let launcher = ScriptedPlayerLauncher(exit: Self.done)
        let player = CalibrationPlayer(launcher: launcher)
        try await player.setRate(device: "D10s", hz: 96_000)
        try await player.play(device: "D10s", file: URL(filePath: "/tmp/run file.wav"))
        #expect(
            launcher.calls == [["rate", "D10s", "96000"], ["play", "D10s", "/tmp/run file.wav"]])
    }

    @Test func aNonZeroExitGivesItsErrorOutput() async {
        let launcher = ScriptedPlayerLauncher(
            exit: PlayerExit(status: 1, errorOutput: "no output device matches \"x\"\n"))
        let player = CalibrationPlayer(launcher: launcher)
        await #expect(throws: PlayerFailure.failed("no output device matches \"x\"")) {
            try await player.setRate(device: "x", hz: 48_000)
        }
    }

    @Test func aSecondCallWhileOneRunsIsRefused() async throws {
        let launcher = ScriptedPlayerLauncher(exit: nil)
        let player = CalibrationPlayer(launcher: launcher)
        let playing = Task { try await player.play(device: "D10s", file: URL(filePath: "/a.wav")) }
        try await Self.waitUntil { launcher.players.first?.isWaiting == true }
        await #expect(throws: PlayerFailure.busy) {
            try await player.setRate(device: "D10s", hz: 48_000)
        }
        player.stop()
        _ = await playing.result
        #expect(launcher.calls.count == 1)
    }

    @Test func cancellingAPlayStopsTheChild() async throws {
        let launcher = ScriptedPlayerLauncher(exit: nil)
        let player = CalibrationPlayer(launcher: launcher)
        let playing = Task { try await player.play(device: "D10s", file: URL(filePath: "/a.wav")) }
        try await Self.waitUntil { launcher.players.first?.isWaiting == true }
        playing.cancel()
        let result = await playing.result
        #expect(throws: PlayerFailure.cancelled) { try result.get() }
        #expect(launcher.players.first?.stopCount == 1)
    }

    @Test func theRealProcessReportsItsExitAndErrors() async throws {
        let launcher = ProcessPlayerLauncher(executable: URL(filePath: "/bin/sh"))
        let running = try launcher.launch(["-c", "echo out; echo 'bad device' >&2; exit 3"])
        let exit = await running.wait()
        #expect(exit == PlayerExit(status: 3, errorOutput: "bad device\n"))
    }

    private static func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<500 where !condition() {
            try await Task.sleep(for: .milliseconds(2))
        }
        #expect(condition())
    }
}
