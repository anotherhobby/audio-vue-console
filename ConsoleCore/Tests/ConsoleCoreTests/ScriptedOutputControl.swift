import Synchronization

@testable import ConsoleCore

/// An `OutputControl` over fixed devices: it holds each device's rate and format, records every
/// set, refuses where told to, and yields a change whenever `change(_:)` is called.
final class ScriptedOutputControl: OutputControl {
    private struct State {
        var devices: [OutputDevice]
        var current: [String: OutputCurrent]
        var refusal: OutputFailure?
        var rateSets: [Int] = []
        var formatSets: [OutputFormat] = []
        var listeners: [AsyncStream<Void>.Continuation] = []
    }

    private let state: Mutex<State>

    init(_ devices: [OutputDevice], current: [String: OutputCurrent]) {
        state = Mutex(State(devices: devices, current: current))
    }

    var rateSets: [Int] { state.withLock { $0.rateSets } }
    var formatSets: [OutputFormat] { state.withLock { $0.formatSets } }

    /// Makes every later set fail with `failure`, or succeed again with nil.
    func refuse(with failure: OutputFailure?) {
        state.withLock { $0.refusal = failure }
    }

    /// Changes a device as Audio MIDI Setup would, and tells every follower.
    func change(_ uid: String, to current: OutputCurrent) {
        let listeners = state.withLock { state in
            state.current[uid] = current
            return state.listeners
        }
        for listener in listeners { listener.yield() }
    }

    func list() -> [OutputDevice] {
        state.withLock { $0.devices }
    }

    func current(uid: String) -> OutputCurrent? {
        state.withLock { $0.current[uid] }
    }

    func setRate(uid: String, hz: Int) throws(OutputFailure) {
        let refusal = state.withLock { state -> OutputFailure? in
            state.rateSets.append(hz)
            guard state.refusal == nil, let format = state.current[uid]?.format else {
                return state.refusal
            }
            state.current[uid] = OutputCurrent(rate: hz, format: format)
            return nil
        }
        if let refusal { throw refusal }
    }

    func setFormat(uid: String, _ format: OutputFormat) throws(OutputFailure) {
        let refusal = state.withLock { state -> OutputFailure? in
            state.formatSets.append(format)
            guard state.refusal == nil, let rate = state.current[uid]?.rate else {
                return state.refusal
            }
            state.current[uid] = OutputCurrent(rate: rate, format: format)
            return nil
        }
        if let refusal { throw refusal }
    }

    func changes(uid: String) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        state.withLock { $0.listeners.append(continuation) }
        return stream
    }
}
