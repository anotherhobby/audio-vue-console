import Foundation
import Observation

/// One calibration run from this Mac, in `make calibrate`'s order: render the file, set the
/// device's rate and let the chain settle, arm, then play once the arm is done (`calibration-run`,
/// design D3). The step shown follows the panel's lifecycle word; the ending comes only from the
/// ended calibration the panel names for this run's arm. The app holds one, so it outlives the
/// window and a quit can reach it.
@MainActor @Observable
public final class CalibrationSession {
    public enum Step: Equatable, Sendable {
        case rendering
        case settling
        case arming
        /// The file plays until this time.
        case playing(until: Date)
        case armed
        case measuring
        case analysing
    }

    public enum Ending: Equatable, Sendable {
        /// The run completed. A reason says which stimulus was missing, where it cannot apply, or
        /// that its report was not written.
        case completed(runID: String?, applicable: Bool, reason: String?)
        case failed(reason: String?)
        case expired(reason: String?)
        /// The panel refused the arm, or did not answer it, with its words.
        case refused(String)
        case stimulusRefused(String)
        case stimulusFailed(String)
        case playerFailed(String)
        case hostFailed(HostFailure)
        case cancelled
    }

    public private(set) var step: Step?
    public private(set) var ending: Ending?
    /// The panel's words on a cancel it refused, while the run goes on.
    public private(set) var note: String?
    public var isUnderWay: Bool { step != nil }

    private let player: CalibrationPlayer
    private let stimulus: any StimulusSource
    private let client: HostClient
    private let now: @Sendable () -> Date
    private var run: Active?

    /// What the run under way holds: where it arms, its file, its arm's id once armed.
    private struct Active {
        let host: CalibrationHost
        var file: URL?
        var arm: String?
        var task: Task<Void, Never>?
        var cancelAsked = false
        /// The step the lifecycle word gives, shown once the file has played.
        var panelStep: Step?
    }

    public init(
        player: CalibrationPlayer, stimulus: any StimulusSource, client: HostClient = HostClient(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.player = player
        self.stimulus = stimulus
        self.client = client
        self.now = now
    }

    /// Starts a run, unless one is under way.
    @discardableResult
    public func start(_ stated: StatedRun, device: String, host: CalibrationHost) -> Bool {
        guard run == nil else { return false }
        ending = nil
        note = nil
        step = .rendering
        run = Active(host: host)
        run?.task = Task { await perform(stated, device: device) }
        return true
    }

    /// Stops the run at whatever step it has reached. Before the arm nothing is sent; from the arm
    /// on, playback stops and the panel is sent a cancel.
    public func cancel() {
        guard var active = run else { return }
        guard step != .arming else {
            active.cancelAsked = true
            run = active
            return
        }
        active.task?.cancel()
        guard active.arm != nil else { return finish(.cancelled) }
        Task { await cancelAtHost(active.host) }
    }

    /// Follows the panel's state: its lifecycle word for the step, and the ended calibration for
    /// this run's ending, matched by the arm's id.
    public func observe(_ state: PanelState) {
        guard let arm = run?.arm else { return }
        if let ended = state.endedCalibration, ended.arm == arm {
            player.stop()
            return finish(Self.ending(ended))
        }
        guard let shown = Self.step(state.calibrationLifecycle) else { return }
        run?.panelStep = shown
        if case .playing = step { return }
        step = shown
    }

    private func perform(_ stated: StatedRun, device: String) async {
        guard let file = await render(stated), await settle(device, stated.rate) else { return }
        guard await arm(stated) else { return }
        await play(file, on: device)
    }

    private func render(_ stated: StatedRun) async -> URL? {
        do {
            let file = try await stimulus.file(for: stated)
            guard run != nil else {
                Self.remove(file)
                return nil
            }
            run?.file = file
            return file
        } catch {
            finish(Self.ending(error))
            return nil
        }
    }

    private func settle(_ device: String, _ rate: Int) async -> Bool {
        step = .settling
        do {
            try await player.setRate(device: device, hz: rate)
        } catch {
            finish(Self.ending(error))
            return false
        }
        guard run != nil else { return false }
        step = .arming
        return true
    }

    private func arm(_ stated: StatedRun) async -> Bool {
        guard let host = run?.host else { return false }
        let answer: ArmAnswer
        do {
            answer = try await client.arm(stated, at: host.address, token: host.token)
        } catch {
            finish(.hostFailed(error))
            return false
        }
        guard case .done = answer.outcome, let arm = answer.arm else {
            finish(.refused(Self.words(answer.outcome)))
            return false
        }
        run?.arm = arm
        step = .armed
        guard run?.cancelAsked != true else {
            await cancelAtHost(host)
            return false
        }
        return true
    }

    private func play(_ file: URL, on device: String) async {
        let seconds = WAVHeader(contentsOf: file)?.seconds ?? 0
        step = .playing(until: now().addingTimeInterval(seconds))
        do {
            try await player.play(device: device, file: file)
            if run != nil { step = run?.panelStep ?? .measuring }
        } catch {
            guard error != .cancelled, let host = run?.host else { return }
            _ = await sendCancel(host)
            finish(Self.ending(error))
        }
    }

    private func cancelAtHost(_ host: CalibrationHost) async {
        guard let answer = await sendCancel(host) else { return }
        switch answer.outcome {
        case .done where answer.recordStands:
            step = run?.panelStep ?? .analysing
        case .done:
            finish(.cancelled)
        default:
            note = Self.words(answer.outcome)
            step = run?.panelStep ?? .measuring
        }
    }

    private func sendCancel(_ host: CalibrationHost) async -> CancelAnswer? {
        do {
            return try await client.cancelCalibration(at: host.address, token: host.token)
        } catch {
            finish(.hostFailed(error))
            return nil
        }
    }

    /// Ends the run once, removing its file.
    private func finish(_ ending: Ending) {
        guard let active = run else { return }
        if let file = active.file { Self.remove(file) }
        run = nil
        step = nil
        self.ending = ending
    }

    private static func remove(_ file: URL) {
        do {
            try FileManager.default.removeItem(at: file)
        } catch {
            // Already gone, or in the temporary directory the system clears.
        }
    }
}
