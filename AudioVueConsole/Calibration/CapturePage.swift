import ConsoleCore
import SwiftUI

/// The Capture page: the panel's input, the calibration in force from the live state, Calibrate…
/// and the pass under way, and the host's runs, newest first (`capture-input`, `calibration-run`,
/// `calibration-pass`, `calibration-history`). The input and the runs are read when the page opens,
/// and the runs again as each rate ends. A one-rate pass then opens its report; a pass of every
/// rate ends with its summary and opens none. The models do the work, and this only shows them.
struct CapturePage: View {
    @Bindable var connection: HostConnection
    let live: LiveState?
    let renderer: Renderer
    let pass: CalibrationPass?
    @State private var input: PanelInput?
    @State private var output: MacOutput?
    @State private var runs: CalibrationRuns?
    /// The run whose report is open.
    @State private var opened: RunEntry?
    @State private var isAsking = false

    var body: some View {
        NavigationStack {
            CaptureForm(
                rows: CalibrationRows(state: connection.isPaired == true ? live?.state : nil),
                runs: runs?.runs ?? [], listing: listing, open: { opened = $0 }
            ) {
                InputSection(
                    input: input, output: output, isPanelDown: live?.state?.condition == .down,
                    lock: inputLock)
            } calibrate: {
                CalibrateSection(
                    readiness: readiness, pass: pass, runs: runs?.runs ?? [],
                    open: { opened = $0 }
                ) { isAsking = true }
            }
            .navigationTitle("Capture")
            .navigationDestination(item: $opened) { RunReport(run: $0, runs: runs) }
        }
        .sheet(isPresented: $isAsking) { sheet }
        .task(id: connection.isPaired) {
            input = connection.makePanelInput()
            output = connection.makeMacOutput()
            output?.load()
            runs = connection.makeCalibrationRuns()
            await input?.load()
            await runs?.load()
        }
        .task(id: followID) { await output?.follow() }
        .onChange(of: pass?.session.ending) { _, ending in Task { await ended(ending) } }
    }

    @ViewBuilder private var sheet: some View {
        if case .ready(let rate) = readiness {
            CalibrateSheet(rate: rate, hostRates: input?.rates, device: output?.device) {
                start($0, $1, on: $2)
            }
        }
    }

    /// Whether a calibration has the panel: this app's pass, any run the panel reports, or the
    /// hold after a run, which the panel reports at an ended word (design D11).
    private var inputLock: InputLock {
        if pass?.isUnderWay == true { return .calibrating }
        switch live?.state?.calibrationLifecycle {
        case nil, .off?: return .free
        case .done?, .failed?, .expired?: return .holding(rate: live?.state?.rateHz)
        case .waiting?, .arming?, .running?, .analysing?: return .calibrating
        }
    }

    /// What following this Mac's output hangs on: nil with no output, else its device's id, empty
    /// with no device, so following starts again when either changes.
    private var followID: String? {
        output.map { $0.device?.uid ?? "" }
    }

    private var readiness: CalibrationReadiness {
        CalibrationReadiness(
            paired: connection.isPaired == true, condition: live?.state?.condition,
            verdict: renderer.verdict, installedRate: input?.rate,
            underWay: pass?.isUnderWay ?? false)
    }

    private func start(_ kind: StatedRun.Kind, _ plan: PassPlan, on device: OutputDevice) {
        guard let host = connection.calibrationHost() else { return }
        let returnTo = output?.isSynchronized == true ? input?.rate : nil
        pass?.start(kind: kind, plan: plan, device: device, host: host, returnTo: returnTo)
    }

    /// Reads the runs again once a rate ends, and opens a one-rate pass's completed report.
    private func ended(_ ending: CalibrationSession.Ending?) async {
        guard let ending else { return }
        await runs?.load()
        guard pass?.isMultiRate == false, case .completed(let runID?, _, _) = ending else { return }
        opened = runs?.runs.first { $0.id == runID }
    }

    /// What the runs list says in place of runs, where it has none to show.
    private var listing: RunsListing {
        switch runs?.state {
        case nil, .unpaired?: .notPaired
        case .idle?, .loading?: (runs?.runs.isEmpty ?? true) ? .loading : .shown
        case .loaded?: .shown
        case .failed(let failure)?: .failed(ReadFailureText.text(failure))
        }
    }
}

/// Why a read from the host failed, in words for the Capture page.
enum ReadFailureText {
    static func text(_ failure: HostFailure) -> String {
        switch failure {
        case .unreachable: "the host couldn't be reached."
        case .notFound: "the host no longer has it."
        case .tokenRefused: "the host no longer takes this app's pairing. Pair again."
        case .conflict(let reason): reason
        case .refused, .unexpectedAnswer, .pairingRefused, .unknownClient, .stale, .invalid,
            .imageRefused:
            "the host answered in a way this app didn't expect."
        }
    }
}

/// What the runs list shows: the runs, or why there are none to show.
enum RunsListing: Equatable {
    case notPaired
    case loading
    case shown
    case failed(String)
}

/// The Capture page for given values, so previews can show each.
struct CaptureForm<Input: View, Calibrate: View>: View {
    let rows: CalibrationRows
    let runs: [RunEntry]
    let listing: RunsListing
    /// Opens a run's report.
    var open: (RunEntry) -> Void = { _ in }
    /// The Input section.
    @ViewBuilder var input: Input
    /// Calibrate…, or the pass under way.
    @ViewBuilder var calibrate: Calibrate

    var body: some View {
        Form {
            input
            Section {
                ForEach(rows.inForce.rows) { PanelRowView(row: $0) }
            } header: {
                Text(rows.inForce.title)
            } footer: {
                if let note = rows.inForce.note { Text(note).foregroundStyle(.orange) }
            }
            Section {
                calibrate
            } footer: {
                Text(CalibrateSheet.whereItPlays)
            }
            Section("Calibration History") {
                RunsList(runs: runs, listing: listing, open: open)
            }
        }
        .formStyle(.grouped)
    }
}

/// The host's runs, newest first, each by its date and time here, or its id where that is not a
/// date, and whether it has a report. Clicking a run opens it.
struct RunsList: View {
    let runs: [RunEntry]
    let listing: RunsListing
    let open: (RunEntry) -> Void

    var body: some View {
        switch listing {
        case .notPaired: Text("Pair with the panel to see its runs.").foregroundStyle(.secondary)
        case .loading: ProgressView().controlSize(.small)
        case .failed(let reason):
            Label("Couldn't read the runs: \(reason)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .shown where runs.isEmpty: Text("No runs yet.").foregroundStyle(.secondary)
        case .shown:
            ForEach(runs) { run in
                Button {
                    open(run)
                } label: {
                    RunRow(run: run).contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One run: when it started, its kind and rate, and whether it has a report.
struct RunRow: View {
    let run: RunEntry

    var body: some View {
        LabeledContent {
            if run.hasReport {
                Image(systemName: "doc.text").accessibilityLabel("Has a report")
            } else {
                Text("No report").foregroundStyle(.secondary)
            }
        } label: {
            Text(run.title)
            Text("\(RunKindText.text(run.kind)) · \(run.rate.map(RateText.text) ?? "—")")
        }
    }
}

#Preview("Calibrated, with runs") {
    let json = #"""
        {"condition": "up", "sections": {"calibration": {
          "status": "calibrated", "run_id": "2026-11-01T14-55-02Z", "age_days": 7.2,
          "trim_db": 0.01, "noise_floor_dbfs": -118.4}}}
        """#
    let state: PanelState? =
        switch Result(catching: { () throws(HostFailure) in try PanelState(json: Data(json.utf8)) })
        {
        case .success(let state): state
        case .failure: nil
        }
    return CaptureForm(
        rows: CalibrationRows(state: state),
        runs: [
            RunEntry(
                id: "2026-11-01T14-55-02Z", hasReport: true, kind: "calibration", rate: 96_000),
            RunEntry(
                id: "2026-10-25T23-16-08Z", hasReport: false, kind: "characterization",
                rate: 44_100),
            RunEntry(id: "manual-1", hasReport: true, kind: "calibration"),
        ],
        listing: .shown
    ) {
        InputFields(
            listing: .shown(
                InputShown(
                    choice: InputChoice(device: "hw:CARD=D10s,DEV=0", rate: 96_000),
                    devices: ["hw:CARD=D10s,DEV=0"],
                    rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000])),
            selection: .constant(InputChoice(device: "hw:CARD=D10s,DEV=0", rate: 96_000)),
            lock: .free)
    } calibrate: {
        Button("Calibrate…") {}
    }
    .frame(width: 640, height: 720)
}

#Preview("Not paired") {
    CaptureForm(rows: CalibrationRows(state: nil), runs: [], listing: .notPaired) {
        InputFields(
            listing: .notPaired, selection: .constant(InputChoice(rate: 0)), lock: .free)
    } calibrate: {
        CalibrateSection(readiness: .notReady("Pair with the panel to calibrate it."), pass: nil)
    }
    .frame(width: 640, height: 520)
}
