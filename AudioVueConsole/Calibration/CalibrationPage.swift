import ConsoleCore
import SwiftUI

/// The Calibration page: the calibration in force from the live state, Calibrate… and the run
/// under way, and the host's runs, newest first (`calibration-run`, `calibration-history`). The
/// runs are read when the page opens and when a run ends, whose report then opens. The models do
/// the work, and this only shows them.
struct CalibrationPage: View {
    @Bindable var connection: HostConnection
    let live: LiveState?
    let renderer: Renderer
    let session: CalibrationSession?
    @State private var runs: CalibrationRuns?
    /// The run whose report is open.
    @State private var opened: RunEntry?
    @State private var isAsking = false

    var body: some View {
        NavigationStack {
            CalibrationForm(
                rows: CalibrationRows(state: connection.isPaired == true ? live?.state : nil),
                runs: runs?.runs ?? [], listing: listing, open: { opened = $0 }
            ) {
                CalibrateSection(readiness: readiness, session: session) { isAsking = true }
            }
            .navigationTitle("Calibration")
            .navigationDestination(item: $opened) { RunReport(run: $0, runs: runs) }
        }
        .sheet(isPresented: $isAsking) { sheet }
        .task(id: connection.isPaired) {
            runs = connection.makeCalibrationRuns()
            await runs?.load()
        }
        .onChange(of: session?.ending) { _, ending in Task { await ended(ending) } }
    }

    @ViewBuilder private var sheet: some View {
        if case .ready(let rate) = readiness {
            CalibrateSheet(rate: rate, hostID: connection.host?.id) { start($0, on: $1) }
        }
    }

    private var readiness: CalibrationReadiness {
        CalibrationReadiness(
            paired: connection.isPaired == true, condition: live?.state?.condition,
            verdict: renderer.verdict, installedRate: runs?.installedRate,
            underWay: session?.isUnderWay ?? false)
    }

    private func start(_ run: StatedRun, on device: OutputDevice) {
        guard let host = connection.calibrationHost() else { return }
        session?.start(run, device: device.name, host: host)
    }

    /// Reads the runs again once a run ends, and opens a completed run's report.
    private func ended(_ ending: CalibrationSession.Ending?) async {
        guard let ending else { return }
        await runs?.load()
        guard case .completed(let runID?, _, _) = ending else { return }
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

/// Why a read from the host failed, in words for the Calibration page.
enum ReadFailureText {
    static func text(_ failure: HostFailure) -> String {
        switch failure {
        case .unreachable: "the host couldn't be reached."
        case .notFound: "the host no longer has it."
        case .tokenRefused: "the host no longer takes this app's pairing. Pair again."
        case .conflict(let reason): reason
        case .refused, .unexpectedAnswer, .pairingRefused, .unknownClient, .stale, .invalid:
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

/// The Calibration page for given values, so previews can show each.
struct CalibrationForm<Calibrate: View>: View {
    let rows: CalibrationRows
    let runs: [RunEntry]
    let listing: RunsListing
    /// Opens a run's report.
    var open: (RunEntry) -> Void = { _ in }
    /// Calibrate…, or the run under way.
    @ViewBuilder var calibrate: Calibrate

    var body: some View {
        Form {
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
            Section("Runs") { RunsList(runs: runs, listing: listing, open: open) }
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

/// One run: when it started, its kind, and whether it has a report.
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
            Text(RunKindText.text(run.kind))
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
    return CalibrationForm(
        rows: CalibrationRows(state: state),
        runs: [
            RunEntry(id: "2026-11-01T14-55-02Z", hasReport: true, kind: "calibration"),
            RunEntry(id: "2026-10-25T23-16-08Z", hasReport: false, kind: "characterization"),
            RunEntry(id: "manual-1", hasReport: true, kind: "calibration"),
        ],
        listing: .shown
    ) {
        Button("Calibrate…") {}
    }
    .frame(width: 640, height: 560)
}

#Preview("Not paired") {
    CalibrationForm(rows: CalibrationRows(state: nil), runs: [], listing: .notPaired) {
        CalibrateSection(readiness: .notReady("Pair with the panel to calibrate it."), session: nil)
    }
    .frame(width: 640, height: 480)
}
