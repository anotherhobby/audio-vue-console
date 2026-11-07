import Foundation

/// Why a request to the render helper came to nothing (`render-helper`).
public enum RenderFailure: Error, Sendable, Equatable {
    /// The helper could not be started, and why.
    case unavailable(String)
    /// The helper ended, or answered with what its protocol does not allow. The next request
    /// starts a new one.
    case ended
    /// The helper refused the scene, with the panel's own reason. It keeps running.
    case refused(String)
    /// The helper did not take the request, saying why. It keeps running.
    case failed(String)
}

/// The render helper's client (design D2): it starts the helper when first asked, sends one
/// request at a time and reads its whole answer before the next, and starts a new helper after one
/// ends.
public actor RenderHelper {
    private let launcher: any HelperLauncher
    private var running: (any RunningHelper)?
    private var reader = HelperAnswerReader()
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    public init(launcher: any HelperLauncher) {
        self.launcher = launcher
    }

    /// The digest of the code the helper draws with.
    public func hello() async throws(RenderFailure) -> String {
        let answer = try await ask(.object(["op": .string("hello")]))
        guard let digest = answer.header["cards"]?.stringValue else {
            drop()
            throw .ended
        }
        return digest
    }

    /// Asks the helper to make the run for `analysis` at `rate`, answering once it is made.
    public func prepare(analysis: JSONValue, rate: Int) async throws(RenderFailure) {
        _ = try await ask(
            .object(["op": .string("prepare"), "analysis": analysis, "rate": .integer(rate)]))
    }

    /// Sends one request, `message` holding its `op`, and reads its whole answer.
    public func ask(_ message: JSONValue) async throws(RenderFailure) -> HelperAnswer {
        await acquire()
        defer { release() }
        let helper = try current()
        do {
            try helper.write(try HelperFrame.encode(message))
        } catch {
            drop()
            throw .ended
        }
        let answer = try await read(from: helper)
        return try Self.accepted(answer)
    }

    /// Ends the helper, as the app does when it quits.
    public func stop() {
        drop()
    }

    private func current() throws(RenderFailure) -> any RunningHelper {
        if let running { return running }
        do {
            let started = try launcher.launch()
            running = started
            return started
        } catch {
            throw .unavailable(String(describing: error))
        }
    }

    private func read(from helper: any RunningHelper) async throws(RenderFailure) -> HelperAnswer {
        while true {
            do {
                if let answer = try reader.next() { return answer }
            } catch {
                drop()
                throw .ended
            }
            guard let chunk = await helper.nextChunk() else {
                drop()
                throw .ended
            }
            reader.append(chunk)
        }
    }

    /// `answer` where the helper says it is done, or why not.
    private static func accepted(_ answer: HelperAnswer) throws(RenderFailure) -> HelperAnswer {
        if answer.header["ok"] == .bool(true) { return answer }
        if let reason = answer.header["refused"]?.stringValue { throw .refused(reason) }
        throw .failed(answer.header["error"]?.stringValue ?? "The renderer did not take a request.")
    }

    private func drop() {
        running?.stop()
        running = nil
        reader = HelperAnswerReader()
    }

    /// Waits until no other request is under way, so answers are read in the order asked.
    private func acquire() async {
        guard busy else {
            busy = true
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Hands the helper to the next request waiting, or marks it free.
    private func release() {
        if waiting.isEmpty {
            busy = false
        } else {
            waiting.removeFirst().resume()
        }
    }
}
