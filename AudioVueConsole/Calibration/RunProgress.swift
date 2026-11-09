import ConsoleCore
import SwiftUI

/// Calibrate…, offered only where a run can work, else disabled saying why; while a pass is under
/// way, where it is with Cancel; and once it ends, what became of it: one run's ending, or each
/// rate's outcome for a pass of every rate (`calibration-run`, `calibration-pass`).
struct CalibrateSection: View {
    let readiness: CalibrationReadiness
    let pass: CalibrationPass?
    /// The host's runs, for the summary's reports.
    var runs: [RunEntry] = []
    var open: (RunEntry) -> Void = { _ in }
    var ask: () -> Void = {}

    var body: some View {
        if let pass, pass.isUnderWay {
            RunProgress(pass: pass)
        } else {
            if let pass, pass.isMultiRate {
                ForEach(pass.outcomes) { PassSummaryRow(outcome: $0, runs: runs, open: open) }
            } else if let ending = pass?.session.ending {
                EndingRow(ending: ending)
            }
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

/// A pass under way: for a pass of every rate, the rate it is on and its place; the run's step, the
/// time left while the file plays, the panel's words on a refused cancel, and Cancel.
struct RunProgress: View {
    let pass: CalibrationPass

    var body: some View {
        RunProgressRows(
            place: pass.isMultiRate ? pass.current : nil, step: pass.session.step,
            note: pass.session.note, cancel: pass.cancel)
    }

    /// "Rate 3 of 5 · 88.2 kHz".
    static func place(_ current: CalibrationPass.Place) -> String {
        "Rate \(current.index) of \(current.count) · \(RateText.text(current.rate))"
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

/// A pass's progress for given values, so previews can show each.
struct RunProgressRows: View {
    /// The rate under way and its place, for a pass of every rate.
    let place: CalibrationPass.Place?
    let step: CalibrationSession.Step?
    var note: String?
    let cancel: () -> Void

    var body: some View {
        if let place { Text(RunProgress.place(place)).font(.headline) }
        LabeledContent {
            Button("Cancel", role: .cancel, action: cancel)
        } label: {
            HStack {
                ProgressView().controlSize(.small)
                if case .playing(let until) = step {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(RunProgress.playing(until, at: context.date))
                    }
                } else {
                    Text(RunProgress.text(step))
                }
            }
        }
        if let note {
            Label(note, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}

/// One rate of a finished pass: its rate and what became of it, with its report where the host
/// lists the run with one.
struct PassSummaryRow: View {
    let outcome: PassOutcome
    let runs: [RunEntry]
    let open: (RunEntry) -> Void

    var body: some View {
        LabeledContent {
            if let report { Button("Open Report") { open(report) } }
        } label: {
            Text(RateText.text(outcome.rate))
            switch outcome.outcome {
            case .ended(let ending): EndingRow(ending: ending)
            case .skipped: Text("Skipped: this Mac's output can't play it.")
            case .notRun: Text("Not run.")
            }
        }
    }

    /// The completed run's entry in the host's list, where it has a report.
    private var report: RunEntry? {
        guard case .ended(.completed(let runID?, _, _)) = outcome.outcome else { return nil }
        return runs.first { $0.id == runID && $0.hasReport }
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

#Preview("A pass under way") {
    Form {
        RunProgressRows(
            place: CalibrationPass.Place(rate: 88_200, index: 3, count: 5),
            step: .playing(until: .now.addingTimeInterval(9))
        ) {}
    }
    .formStyle(.grouped)
    .frame(width: 560, height: 160)
}

#Preview("A pass's summary") {
    let runs = [RunEntry(id: "r1", hasReport: true, kind: "calibration", rate: 44_100)]
    Form {
        ForEach(
            [
                PassOutcome(
                    rate: 44_100,
                    outcome: .ended(.completed(runID: "r1", applicable: true, reason: nil))),
                PassOutcome(rate: 48_000, outcome: .ended(.expired(reason: nil))),
                PassOutcome(rate: 88_200, outcome: .ended(.cancelled)),
                PassOutcome(rate: 96_000, outcome: .notRun),
                PassOutcome(rate: 192_000, outcome: .skipped),
            ]
        ) { PassSummaryRow(outcome: $0, runs: runs) { _ in } }
    }
    .formStyle(.grouped)
    .frame(width: 560, height: 360)
}
