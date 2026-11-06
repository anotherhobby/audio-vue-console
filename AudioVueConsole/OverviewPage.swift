import ConsoleCore
import SwiftUI

/// The Overview: what the host says about its panel, with a dash for what it has not said, and
/// connecting and pairing in one spot, last (`panel-window`). The connection and the live state do
/// the work; this only shows them.
struct OverviewPage: View {
    @Bindable var connection: HostConnection
    let live: LiveState?
    let addPanel: () -> Void
    @State private var clients: PairedClients?

    var body: some View {
        OverviewForm(
            rows: rows, liveNote: liveNote, address: connection.address?.description,
            state: connection.state,
            actions: OverviewActions(pair: { connection.pair() }, addPanel: addPanel)
        ) {
            if let clients { ClientsList(clients: clients) }
        }
        .task(id: ClientsKey(paired: connection.isPaired, isPairing: connection.pairing != nil)) {
            clients = connection.makeClients()
            await clients?.load()
        }
        .sheet(item: $connection.pairing) { PairingSheet(pairing: $0) }
        .navigationTitle(connection.host?.name ?? connection.address?.description ?? "Overview")
    }

    /// The panel's values while paired, and dashes otherwise.
    private var rows: OverviewRows {
        let paired = connection.isPaired == true
        return OverviewRows(host: paired ? connection.host : nil, state: paired ? live?.state : nil)
    }

    private var liveNote: String? {
        guard connection.isPaired == true, live?.isLive != true else { return nil }
        return live?.state == nil
            ? "Waiting for the host's state."
            : "Not live: the host isn't sending its state. These are its last values."
    }

    /// The clients list is made again when pairing changes, and when a pairing sheet closes, since
    /// pairing again gives a new token.
    private struct ClientsKey: Hashable {
        let paired: Bool?
        let isPairing: Bool
    }
}

/// What the Overview's buttons do.
struct OverviewActions {
    var pair: () -> Void = {}
    var addPanel: () -> Void = {}
}

/// The Overview for given values, so previews can show each.
struct OverviewForm<Clients: View>: View {
    let rows: OverviewRows
    let liveNote: String?
    let address: String?
    let state: HostConnection.State
    var actions = OverviewActions()
    @ViewBuilder var clients: Clients

    var body: some View {
        Form {
            ForEach(rows.sections, id: \.title) { section in
                Section {
                    ForEach(section.rows) { LabeledContent($0.label, value: $0.value) }
                } header: {
                    Text(section.title)
                } footer: {
                    if let note = section.note { Text(note).foregroundStyle(.orange) }
                }
            }
            Section("Pairing") {
                PairingSection(address: address, state: state, actions: actions)
                clients
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top) { liveBanner }
    }

    @ViewBuilder private var liveBanner: some View {
        if let liveNote {
            Label(liveNote, systemImage: "antenna.radiowaves.left.and.right.slash")
                .foregroundStyle(.secondary)
                .padding(.top)
        }
    }
}

/// Where the connection is, what it came to, whether this Mac is paired, and what comes next.
struct PairingSection: View {
    let address: String?
    let state: HostConnection.State
    let actions: OverviewActions

    var body: some View {
        LabeledContent("Address", value: address ?? OverviewRows.dash)
        ConnectionStatus(state: state)
        switch state {
        case .connected(_, _, paired: true):
            Label("This Mac is paired with the host.", systemImage: "link")
            Button("Pair Again…", action: actions.pair)
        case .connected(_, _, paired: false):
            Label(
                "This Mac isn't paired. Pairing takes the code the host's panel shows.",
                systemImage: "link.badge.plus")
            Button("Pair…", action: actions.pair).keyboardShortcut(.defaultAction)
        case .idle:
            Button("Add Panel…", action: actions.addPanel)
        case .invalidAddress, .connecting, .incompatible, .failed:
            EmptyView()
        }
    }
}

#Preview("Not paired") {
    if let address = HostAddress(parsing: "audio-vue"), let api = APIVersion(parsing: "2.1.0") {
        OverviewForm(
            rows: OverviewRows(host: nil, state: nil), liveNote: nil, address: "audio-vue",
            state: .connected(address, HostVersion(api: api, schema: 3), paired: false)
        ) {}
    }
}

#Preview("Paired, up") {
    if let address = HostAddress(parsing: "audio-vue"), let api = APIVersion(parsing: "2.1.0") {
        OverviewForm(
            rows: OverviewRows(host: OverviewPreviews.host, state: OverviewPreviews.up),
            liveNote: nil, address: "audio-vue",
            state: .connected(address, HostVersion(api: api, schema: 3), paired: true)
        ) {
            ClientRows(
                state: .loaded,
                clients: [PairedClient(id: "a", name: "hobbymac", pairedAtText: "2026-11-05")],
                isThisMac: { _ in true })
        }
    }
}

#Preview("Paired, down") {
    if let address = HostAddress(parsing: "audio-vue"), let api = APIVersion(parsing: "2.1.0") {
        OverviewForm(
            rows: OverviewRows(
                host: OverviewPreviews.host, state: OverviewPreviews.down, time: { _ in "07:42" }),
            liveNote: nil, address: "audio-vue",
            state: .connected(address, HostVersion(api: api, schema: nil), paired: true)
        ) {}
    }
}

/// Values for the previews, as the proving host gave them, in the host's own JSON.
private enum OverviewPreviews {
    static let host = HostIdentity(id: "h1", name: "audio-vue", widthPx: nil, heightPx: nil)

    static var up: PanelState? {
        state(
            #"""
            {"condition": "up", "sections": {
              "scene": {"name": "My RTA"},
              "capture": {"device": "hw:CARD=m2x4HD,DEV=0", "rate_hz": 96000},
              "analysis": {"p99_ms": 1.13, "budget_ms": 5.33},
              "calibration": {"status": "uncalibrated"},
              "display": {"width_px": 1920, "height_px": 720}}}
            """#)
    }

    static var down: PanelState? {
        state(#"{"condition": "down", "since": "2026-11-05T13:42:00Z", "sections": {}}"#)
    }

    private static func state(_ json: String) -> PanelState? {
        do {
            return try PanelState(json: Data(json.utf8))
        } catch {
            return nil
        }
    }
}
