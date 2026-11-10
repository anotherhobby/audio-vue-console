import Foundation
import Observation

/// The app's one calibration: a run at each rate of a plan, one after another, each a
/// `CalibrationSession` run (`calibration-pass`, design D4). A single run is a pass of one rate.
/// It goes on past a rate that fails, and ends on Cancel, a lost pairing or the panel going down.
/// Where Synchronize Rates is on, it sets the output back to the capture rate as it ends
/// (`mac-output` design D9). The app holds one, so it outlives the window and a quit can reach it.
@MainActor @Observable
public final class CalibrationPass {
    /// The rate under way and its place among the rates the pass runs, counted from 1.
    public struct Place: Equatable, Sendable {
        public let rate: Int
        public let index: Int
        public let count: Int

        public init(rate: Int, index: Int, count: Int) {
            self.rate = rate
            self.index = index
            self.count = count
        }
    }

    public let session: CalibrationSession
    public private(set) var current: Place?
    /// Every rate of the pass in the host's order, the skipped ones included.
    public private(set) var outcomes: [PassOutcome] = []
    /// True from Start until the last rate ends, the moments between rates included.
    public private(set) var isUnderWay = false

    private var latest: PanelState?
    private var isLive = false
    private var cancelAsked = false
    private let output: any OutputControl

    public init(session: CalibrationSession, output: any OutputControl = CoreAudioOutputControl()) {
        self.session = session
        self.output = output
    }

    /// Whether the pass is of more than one rate, which ends with a summary in place of one run's
    /// ending.
    public var isMultiRate: Bool { outcomes.count > 1 }

    /// Starts a pass of `kind` over `plan`'s rates through `device`, unless one is under way. At its
    /// end the output is set to `returnTo`, the capture rate, where it is given.
    @discardableResult
    public func start(
        kind: StatedRun.Kind, plan: PassPlan, device: OutputDevice, host: CalibrationHost,
        returnTo: Int?
    ) -> Bool {
        guard !isUnderWay, !session.isUnderWay, !plan.runs.isEmpty else { return false }
        isUnderWay = true
        cancelAsked = false
        outcomes = (plan.runs + plan.skipped).sorted().map {
            PassOutcome(rate: $0, outcome: plan.skipped.contains($0) ? .skipped : .notRun)
        }
        Task {
            await perform(kind, rates: plan.runs, device: device.name, host: host)
            returnOutput(device, to: returnTo)
            isUnderWay = false
        }
        return true
    }

    /// Cancels the rate under way and runs no further rate.
    public func cancel() {
        guard isUnderWay else { return }
        cancelAsked = true
        session.cancel()
    }

    /// Follows the panel's state, and whether it is current, passing the state to the run.
    public func observe(_ state: PanelState?, isLive: Bool) {
        latest = state
        self.isLive = isLive
        if let state { session.observe(state) }
    }

    private func perform(
        _ kind: StatedRun.Kind, rates: [Int], device: String, host: CalibrationHost
    ) async {
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Calibrating the panel")
        defer {
            ProcessInfo.processInfo.endActivity(activity)
            current = nil
        }
        var last: CalibrationSession.Ending?
        for (index, rate) in rates.enumerated() {
            guard mayGoOn(after: last) else { return }
            current = Place(rate: rate, index: index + 1, count: rates.count)
            let stated = StatedRun(kind: kind, rate: rate)
            guard let ending = await session.run(stated, device: device, host: host) else { return }
            record(.ended(ending), at: rate)
            last = ending
        }
    }

    /// Whether the next rate may start: nothing before it, or a pass not cancelled whose panel is
    /// still up and current and whose pairing still holds.
    private func mayGoOn(after last: CalibrationSession.Ending?) -> Bool {
        guard let last else { return true }
        return !cancelAsked && last != .cancelled && last != .hostFailed(.tokenRefused)
            && isLive && latest?.condition == .up
    }

    /// Sets `device` to `rate` where it is at another. A refusal is not the pass's to report: the
    /// Input and Output section shows the rates as mismatched.
    private func returnOutput(_ device: OutputDevice, to rate: Int?) {
        guard let rate, let now = output.current(uid: device.uid), now.rate != rate else { return }
        do {
            try output.setRate(uid: device.uid, hz: rate)
        } catch {
            // Left to the section's mismatch row, which reads the output again.
        }
    }

    private func record(_ outcome: RateOutcome, at rate: Int) {
        outcomes = outcomes.map { $0.rate == rate ? PassOutcome(rate: rate, outcome: outcome) : $0 }
    }
}
