import Foundation
import Synchronization

/// How a run of `cal-play` ended: its exit status and what it wrote to standard error.
public struct PlayerExit: Sendable, Equatable {
    public let status: Int32
    public let errorOutput: String

    public init(status: Int32, errorOutput: String) {
        self.status = status
        self.errorOutput = errorOutput
    }
}

/// One running `cal-play`: waited on for its exit, or stopped (design D1).
public protocol RunningPlayer: Sendable {
    func wait() async -> PlayerExit
    func stop()
}

/// Starts `cal-play` on its arguments. The app runs a process; tests script one.
public protocol PlayerLauncher: Sendable {
    func launch(_ arguments: [String]) throws -> any RunningPlayer
}

/// Why a call to `cal-play` did not do what it was asked (`calibration-player`).
public enum PlayerFailure: Error, Equatable {
    /// Another call is running; one runs at a time.
    case busy
    /// `cal-play` could not be started.
    case couldNotStart(String)
    /// `cal-play` exited non-zero, with the reason it wrote to standard error.
    case failed(String)
    /// The call's task was cancelled, and `cal-play` was stopped.
    case cancelled
}

/// Runs the `cal-play` the app carries, one call at a time: a device's rate, then a file's play
/// (`calibration-player`). A cancelled call stops its child.
public final class CalibrationPlayer: Sendable {
    private let launcher: any PlayerLauncher
    private let state = Mutex(State())

    private struct State {
        var busy = false
        var current: (any RunningPlayer)?
    }

    public init(launcher: any PlayerLauncher) {
        self.launcher = launcher
    }

    /// The player bundled in the app's `Contents/Helpers`.
    public static func app() -> CalibrationPlayer {
        let executable = Bundle.main.bundleURL.appending(path: "Contents/Helpers/cal-play")
        return CalibrationPlayer(launcher: ProcessPlayerLauncher(executable: executable))
    }

    /// `cal-play rate <device> <hz>`: sets the device's rate, holding while the chain settles if
    /// that changed it.
    public func setRate(device: String, hz: Int) async throws(PlayerFailure) {
        try await run(["rate", device, String(hz)])
    }

    /// `cal-play play <device> <file>`: plays the file once, to its end.
    public func play(device: String, file: URL) async throws(PlayerFailure) {
        try await run(["play", device, file.path(percentEncoded: false)])
    }

    /// Stops whatever is running, as the app quits.
    public func stop() {
        state.withLock { $0.current }?.stop()
    }

    private func run(_ arguments: [String]) async throws(PlayerFailure) {
        let player = try start(arguments)
        defer { state.withLock { $0 = State() } }
        let exit = await withTaskCancellationHandler {
            await player.wait()
        } onCancel: {
            player.stop()
        }
        if Task.isCancelled { throw .cancelled }
        guard exit.status == 0 else { throw .failed(Self.reason(exit)) }
    }

    private func start(_ arguments: [String]) throws(PlayerFailure) -> any RunningPlayer {
        let reserved = state.withLock { state -> Bool in
            guard !state.busy else { return false }
            state.busy = true
            return true
        }
        guard reserved else { throw .busy }
        do {
            let player = try launcher.launch(arguments)
            state.withLock { $0.current = player }
            return player
        } catch {
            state.withLock { $0 = State() }
            throw .couldNotStart(error.localizedDescription)
        }
    }

    private static func reason(_ exit: PlayerExit) -> String {
        let text = exit.errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "cal-play stopped with status \(exit.status)." : text
    }
}

/// Runs `cal-play` with Foundation's `Process`, its output discarded and its errors kept.
public struct ProcessPlayerLauncher: PlayerLauncher {
    let executable: URL

    public init(executable: URL) {
        self.executable = executable
    }

    public func launch(_ arguments: [String]) throws -> any RunningPlayer {
        try ProcessRunningPlayer(executable: executable, arguments: arguments)
    }
}

/// One `cal-play` process. Its exit is known once it has terminated and its standard error has
/// been read to the end, whichever comes last.
final class ProcessRunningPlayer: RunningPlayer {
    private let process = Mutex(Process())
    private let state = Mutex(State())

    private struct State {
        var status: Int32?
        var errors: Data?
        var waiter: CheckedContinuation<PlayerExit, Never>?
    }

    init(executable: URL, arguments: [String]) throws {
        let errors = Pipe()
        try process.withLock { process in
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errors
            process.terminationHandler = { [weak self] ended in
                self?.settle { $0.status = ended.terminationStatus }
            }
            try process.run()
        }
        let reading = errors.fileHandleForReading
        DispatchQueue.global().async { [weak self] in
            let data = reading.readDataToEndOfFile()
            self?.settle { $0.errors = data }
        }
    }

    func wait() async -> PlayerExit {
        await withCheckedContinuation { continuation in
            let exit = state.withLock { state -> PlayerExit? in
                if let done = Self.exit(state) { return done }
                state.waiter = continuation
                return nil
            }
            if let exit { continuation.resume(returning: exit) }
        }
    }

    func stop() {
        process.withLock { process in
            if process.isRunning { process.terminate() }
        }
    }

    private func settle(_ change: (inout State) -> Void) {
        let ready = state.withLock {
            state -> (CheckedContinuation<PlayerExit, Never>, PlayerExit)? in
            change(&state)
            guard let exit = Self.exit(state), let waiter = state.waiter else { return nil }
            state.waiter = nil
            return (waiter, exit)
        }
        if let (waiter, exit) = ready { waiter.resume(returning: exit) }
    }

    private static func exit(_ state: State) -> PlayerExit? {
        guard let status = state.status, let errors = state.errors else { return nil }
        return PlayerExit(status: status, errorOutput: String(bytes: errors, encoding: .utf8) ?? "")
    }
}
