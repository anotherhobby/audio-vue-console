import Foundation
import Synchronization
import os

/// A running render helper: its standard input to write to, its standard output's chunks to read,
/// and the means to end it (design D2). The app runs a process; tests script one.
public protocol RunningHelper: Sendable {
    func write(_ data: Data) throws
    /// The next chunk of standard output, or nil once it has ended.
    func nextChunk() async -> Data?
    /// Closes standard input, which ends the helper, and stops it if it is still running.
    func stop()
}

/// Starts render helpers, one per call.
public protocol HelperLauncher: Sendable {
    func launch() throws -> any RunningHelper
}

/// Chunks handed from the side that receives them to the one reader that waits for them.
final class ChunkChannel: Sendable {
    private struct State {
        var chunks: [Data] = []
        var ended = false
        var waiter: CheckedContinuation<Data?, Never>?
    }

    private let state = Mutex(State())

    func send(_ chunk: Data) {
        let waiter = state.withLock { state -> CheckedContinuation<Data?, Never>? in
            guard !state.ended else { return nil }
            guard let waiter = state.waiter else {
                state.chunks.append(chunk)
                return nil
            }
            state.waiter = nil
            return waiter
        }
        waiter?.resume(returning: chunk)
    }

    func finish() {
        let waiter = state.withLock { state -> CheckedContinuation<Data?, Never>? in
            state.ended = true
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume(returning: nil)
    }

    func next() async -> Data? {
        await withCheckedContinuation { continuation in
            let ready = state.withLock { state -> Data?? in
                if !state.chunks.isEmpty { return .some(state.chunks.removeFirst()) }
                if state.ended { return .some(nil) }
                state.waiter = continuation
                return nil
            }
            if let ready { continuation.resume(returning: ready) }
        }
    }
}

/// Runs the helper with Foundation's `Process`: `executable` on `arguments`, with the caches it
/// writes kept in `caches`, which must be the app's own (`render-helper`).
public struct FoundationHelperLauncher: HelperLauncher {
    let executable: URL
    let arguments: [String]
    let caches: URL
    let errorLine: @Sendable (String) -> Void

    /// The helper the app carries, its caches under Application Support.
    public init(location: HelperLocation) {
        self.init(
            executable: location.interpreter, arguments: [location.script.path],
            caches: URL.applicationSupportDirectory.appending(path: "RenderHelper"),
            errorLine: Self.log)
    }

    init(
        executable: URL, arguments: [String], caches: URL,
        errorLine: @escaping @Sendable (String) -> Void
    ) {
        self.executable = executable
        self.arguments = arguments
        self.caches = caches
        self.errorLine = errorLine
    }

    public func launch() throws -> any RunningHelper {
        let numba = caches.appending(path: "numba")
        let bytecode = caches.appending(path: "pycache")
        for directory in [numba, bytecode] {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        }
        var environment = ProcessInfo.processInfo.environment
        environment["NUMBA_CACHE_DIR"] = numba.path
        environment["PYTHONPYCACHEPREFIX"] = bytecode.path
        environment["PYTHONNOUSERSITE"] = "1"
        return try FoundationRunningHelper(
            executable: executable, arguments: arguments, environment: environment,
            errorLine: errorLine)
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AudioVueConsole", category: "render-helper")

    private static func log(_ line: String) {
        logger.notice("\(line, privacy: .public)")
    }
}

/// One helper process: its output read as it arrives, its errors sent on line by line, so neither
/// pipe fills and stops it.
final class FoundationRunningHelper: RunningHelper {
    private let process = Mutex(Process())
    private let input: FileHandle
    private let output = ChunkChannel()

    init(
        executable: URL, arguments: [String], environment: [String: String],
        errorLine: @escaping @Sendable (String) -> Void
    ) throws {
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        input = stdin.fileHandleForWriting
        let channel = output
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                channel.finish()
            } else {
                channel.send(chunk)
            }
        }
        let lines = LineSplitter(errorLine)
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty { handle.readabilityHandler = nil }
            lines.take(chunk)
        }
        try process.withLock { process in
            process.executableURL = executable
            process.arguments = arguments
            process.environment = environment
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr
            try process.run()
        }
    }

    func write(_ data: Data) throws {
        try input.write(contentsOf: data)
    }

    func nextChunk() async -> Data? {
        await output.next()
    }

    func stop() {
        do {
            try input.close()
        } catch {
            // Already closed: the helper has gone.
        }
        process.withLock { process in
            if process.isRunning { process.terminate() }
        }
    }
}

/// Text arriving in chunks, sent on a whole line at a time.
final class LineSplitter: Sendable {
    private let pending = Mutex(Data())
    private let line: @Sendable (String) -> Void

    init(_ line: @escaping @Sendable (String) -> Void) {
        self.line = line
    }

    /// Takes `chunk`; an empty chunk is the end, which sends any last part line.
    func take(_ chunk: Data) {
        let newline = UInt8(ascii: "\n")
        let whole = pending.withLock { pending -> [Data] in
            pending.append(chunk)
            var lines = pending.split(separator: newline, omittingEmptySubsequences: false)
            pending = chunk.isEmpty ? Data() : Data(lines.removeLast())
            return lines.map { Data($0) }
        }
        for bytes in whole where !bytes.isEmpty {
            line(String(bytes: bytes, encoding: .utf8) ?? "(\(bytes.count) bytes, not UTF-8)")
        }
    }
}
