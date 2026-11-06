import ConsoleCore
import SwiftUI

/// The Panel page: what the host says about its panel, with a dash for what it has not said, and
/// connecting and pairing in one spot, last, led by a prompt to pair while not paired
/// (`panel-window`). The connection and the live state do the work; this only shows them.
struct PanelPage: View {
    @Bindable var connection: HostConnection
    let live: LiveState?
    /// The panel's name as the picker shows it, so the prompt and the status say the same.
    let panelName: String?
    let addPanel: () -> Void
    @State private var clients: PairedClients?

    var body: some View {
        PanelForm(
            rows: rows, liveNote: liveNote, address: connection.address?.description,
            name: panelName, contact: HostContact(live), state: connection.state,
            actions: PanelActions(pair: { connection.pair() }, addPanel: addPanel)
        ) {
            if let clients { ClientsList(clients: clients) }
        }
        .task(id: ClientsKey(paired: connection.isPaired, isPairing: connection.pairing != nil)) {
            clients = connection.makeClients()
            await clients?.load()
        }
        .sheet(item: $connection.pairing) { PairingSheet(pairing: $0) }
        .navigationTitle("Panel")
    }

    /// The panel's values while paired, and dashes otherwise.
    private var rows: PanelRows {
        let paired = connection.isPaired == true
        return PanelRows(host: paired ? connection.host : nil, state: paired ? live?.state : nil)
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

/// What the Panel page's buttons do.
struct PanelActions {
    var pair: () -> Void = {}
    var addPanel: () -> Void = {}
}

/// The Panel page for given values, so previews can show each.
struct PanelForm<Clients: View>: View {
    let rows: PanelRows
    let liveNote: String?
    let address: String?
    var name: String?
    var contact = HostContact.live
    let state: HostConnection.State
    var actions = PanelActions()
    @ViewBuilder var clients: Clients

    var body: some View {
        Form {
            if case .connected(let reached, _, paired: false) = state {
                Section { PairPrompt(name: name ?? reached.description, pair: actions.pair) }
            }
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
                PairingSection(
                    address: address, name: name, state: state, actions: actions, contact: contact)
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

/// What to do while a host answers and this Mac isn't paired: pair (discovery design D10).
struct PairPrompt: View {
    let name: String
    let pair: () -> Void

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text("Pair with \(name) to see and control its panel.").font(.headline)
                Text("Pairing takes the code the host's panel shows.").foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "link.badge.plus")
        }
        Button("Pair…", action: pair).keyboardShortcut(.defaultAction)
    }
}

/// Where the connection is, what it came to, what the host says of itself, and what comes next;
/// while not paired, Pair is in the prompt that leads the page.
struct PairingSection: View {
    let address: String?
    let name: String?
    let state: HostConnection.State
    let actions: PanelActions
    var contact = HostContact.live

    var body: some View {
        LabeledContent("Address", value: address ?? PanelRows.dash)
        ConnectionStatus(name: name, contact: contact, state: state)
        switch state {
        case .connected(_, _, paired: true):
            Button("Pair Again…", action: actions.pair)
        case .idle:
            Button("Add Panel…", action: actions.addPanel)
        case .invalidAddress, .connecting, .connected(_, _, paired: false), .incompatible, .failed,
            .unresolved:
            EmptyView()
        }
    }
}

#Preview("Not paired") {
    if let address = HostAddress(parsing: "audio-vue"), let api = APIVersion(parsing: "2.1.0") {
        PanelForm(
            rows: PanelRows(host: nil, state: nil), liveNote: nil, address: "audio-vue.local",
            name: "audio-vue",
            state: .connected(address, HostVersion(api: api, schema: 3), paired: false)
        ) {}
    }
}

#Preview("Paired, up") {
    if let address = HostAddress(parsing: "audio-vue"), let api = APIVersion(parsing: "2.1.0") {
        PanelForm(
            rows: PanelRows(host: PanelPreviews.host, state: PanelPreviews.up),
            liveNote: nil, address: "audio-vue", name: "audio-vue",
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
        PanelForm(
            rows: PanelRows(
                host: PanelPreviews.host, state: PanelPreviews.down, time: { _ in "07:42" }),
            liveNote: nil, address: "audio-vue", name: "audio-vue",
            state: .connected(address, HostVersion(api: api, schema: nil), paired: true)
        ) {}
    }
}

#Preview("Unreachable") {
    if let address = HostAddress(parsing: "192.0.2.1") {
        PanelForm(
            rows: PanelRows(host: nil, state: nil), liveNote: nil, address: "192.0.2.1",
            name: "192.0.2.1", state: .failed(address, .unreachable)
        ) {}
    }
}

/// The Pairing section in each state, since the page's previews end above it.
#Preview("Pairing section") {
    if let address = HostAddress(parsing: "audio-vue.local"),
        let unreachable = HostAddress(parsing: "192.0.2.1"), let api = APIVersion(parsing: "2.2.0")
    {
        let version = HostVersion(api: api, schema: 1)
        Form {
            Section("Lost contact") {
                PairingSection(
                    address: "audio-vue.local", name: "audio-vue",
                    state: .connected(address, version, paired: true), actions: PanelActions(),
                    contact: .lost)
            }
            Section("Not paired") {
                PairingSection(
                    address: "audio-vue.local", name: "audio-vue",
                    state: .connected(address, version, paired: false), actions: PanelActions())
            }
            Section("Paired") {
                PairingSection(
                    address: "audio-vue.local", name: "audio-vue",
                    state: .connected(address, version, paired: true), actions: PanelActions())
            }
            Section("Unreachable") {
                PairingSection(
                    address: "192.0.2.1", name: "192.0.2.1",
                    state: .failed(unreachable, .unreachable), actions: PanelActions())
            }
        }
        .formStyle(.grouped)
    }
}

/// Values for the previews, as the proving host gave them, in the host's own JSON.
private enum PanelPreviews {
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
