import ConsoleCore
import SwiftUI

/// Calibrate…, offered only where a run can work, else disabled saying why; while a run is under
/// way, where it is with Cancel; and once it ends, what became of it (`calibration-run`).
struct CalibrateSection: View {
    let readiness: CalibrationReadiness
    let session: CalibrationSession?
    var ask: () -> Void = {}

    var body: some View {
        if let session, session.isUnderWay {
            RunProgress(session: session)
        } else {
            if let ending = session?.ending { EndingRow(ending: ending) }
            LabeledContent {
                Button("Calibrate…", action: ask).disabled(!isReady)
            } label: {
                if case .notReady(let reason) = readiness {
                    Text(reason).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var isReady: Bool {
        if case .ready = readiness { return true }
        return false
    }
}

/// A run under way: its step, the time left while the file plays, the panel's words on a refused
/// cancel, and Cancel.
struct RunProgress: View {
    let session: CalibrationSession

    var body: some View {
        LabeledContent {
            Button("Cancel", role: .cancel) { session.cancel() }
        } label: {
            HStack {
                ProgressView().controlSize(.small)
                if case .playing(let until) = session.step {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Self.playing(until, at: context.date))
                    }
                } else {
                    Text(Self.text(session.step))
                }
            }
        }
        if let note = session.note {
            Label(note, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }

    static func text(_ step: CalibrationSession.Step?) -> String {
        switch step {
        case .rendering?: "Making the file…"
        case .settling?: "Setting the output's rate and letting the chain settle…"
        case .arming?: "Arming the panel…"
        case .armed?: "Armed: the panel is listening."
        case .playing?: "Playing…"
        case .measuring?: "Measuring…"
        case .analysing?: "Analysing…"
        case nil: ""
        }
    }

    static func playing(_ until: Date, at now: Date) -> String {
        let left = max(0, Int(until.timeIntervalSince(now).rounded(.up)))
        return "Playing: \(Duration.seconds(left).formatted(.time(pattern: .minuteSecond))) left"
    }
}

/// What became of the last run, in words, with a warning colour where it did not complete.
struct EndingRow: View {
    let ending: CalibrationSession.Ending

    var body: some View {
        if case .completed = ending {
            Label(EndingText.text(ending), systemImage: "checkmark.circle")
        } else {
            Label(EndingText.text(ending), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}

/// A run's ending in words (`calibration-run`, "A run's ending says what became of it").
enum EndingText {
    static func text(_ ending: CalibrationSession.Ending) -> String {
        switch ending {
        case .completed(_, let applicable, let reason): completed(applicable, reason)
        case .failed(let reason): "The run failed: \(reason ?? "the panel gave no reason.")"
        case .expired:
            "The panel heard no file. Check that this Mac's output feeds the panel."
        case .refused(let reason): "The panel didn't arm: \(reason)"
        case .stimulusRefused(let reason): "The file wasn't made: \(reason)"
        case .stimulusFailed(let reason): "The file couldn't be made: \(reason)"
        case .playerFailed(let reason): "Playback failed: \(reason)"
        case .hostFailed(let failure): "The run stopped: \(ReadFailureText.text(failure))"
        case .cancelled: "The run was cancelled."
        }
    }

    private static func completed(_ applicable: Bool, _ reason: String?) -> String {
        guard let reason else { return "The run completed." }
        return applicable
            ? "The run completed, but its report wasn't written: \(reason)"
            : "The run completed, but isn't in force: \(reason)"
    }
}
