import ConsoleCore
import SwiftUI

/// Connecting to one host by the address the user gives, and what came of it, with pairing and the
/// host's clients in sheets. The connection is the app's, so closing the window keeps it. The
/// models do the work; this only shows it.
struct ConnectView: View {
    /// The window's id, which the Host menu opens it by.
    static let windowID = "connect"

    @Bindable var connection: HostConnection

    var body: some View {
        ConnectForm(
            address: $connection.addressText, state: connection.state,
            actions: ConnectionActions(
                connect: { Task { await connection.connect() } },
                pair: { connection.pair() },
                showClients: { connection.showClients() })
        )
        .sheet(item: $connection.pairing) { PairingSheet(pairing: $0) }
        .sheet(item: $connection.clients) { ClientsSheet(clients: $0) }
        .task { await connection.connectAtLaunch() }
    }
}

/// What the connect form's buttons do.
struct ConnectionActions {
    var connect: () -> Void = {}
    var pair: () -> Void = {}
    var showClients: () -> Void = {}
}

/// The connect form for a given state, so previews can show each one.
struct ConnectForm: View {
    @Binding var address: String
    let state: HostConnection.State
    var actions = ConnectionActions()

    private static let minWidth: CGFloat = 440
    private static let minHeight: CGFloat = 440

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField(
                        "Address", text: $address, prompt: Text(verbatim: "audio-vue.local")
                    )
                    .onSubmit(actions.connect)
                    .disabled(isConnecting)
                    Button(isConnectedHere ? "Reconnect" : "Connect", action: actions.connect)
                        .keyboardShortcut(isConnectedHere ? nil : .defaultAction)
                        .disabled(isConnecting || address.isEmpty)
                }
            } footer: {
                Text("A hostname or IPv4 address, with a port if it isn't 19200.")
            }
            Section {
                ConnectionStatus(state: state)
            }
            if case .connected(_, _, let paired) = state {
                Section("Pairing") {
                    PairingSection(paired: paired, actions: actions)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: Self.minWidth, minHeight: Self.minHeight)
    }

    private var isConnecting: Bool {
        if case .connecting = state { return true }
        return false
    }

    /// Whether the address typed is the one the app is connected to, when Connect has nothing left
    /// to do and the next step, pairing, is the default button instead.
    private var isConnectedHere: Bool {
        guard case .connected(let connected, _, _) = state else { return false }
        return HostAddress(parsing: address) == connected
    }
}

/// What a connection came to, in words.
struct ConnectionStatus: View {
    let state: HostConnection.State

    var body: some View {
        switch state {
        case .idle:
            Label("Not connected", systemImage: "circle.dashed")
        case .invalidAddress:
            Label(
                """
                That isn't an address. Give a hostname or IPv4 address, and a port from 1 \
                to 65535.
                """,
                systemImage: "exclamationmark.circle"
            )
            .foregroundStyle(.red)
        case .connecting(let address):
            Label {
                Text("Connecting to \(address.description)…")
            } icon: {
                ProgressView().controlSize(.small)
            }
        case .connected(let address, let version, _):
            connected(address, version)
        case .incompatible(let address, let version):
            incompatible(address, version)
        case .failed(let address, let failure):
            failed(address, failure).foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func connected(_ address: HostAddress, _ version: HostVersion) -> some View {
        Label("Connected to \(address.description)", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
        LabeledContent("API version") { Text(verbatim: version.api.description) }
        LabeledContent("State schema") {
            if let schema = version.schema {
                Text(verbatim: "\(schema)")
            } else {
                Text("Panel not answering")
            }
        }
    }

    private func incompatible(_ address: HostAddress, _ version: HostVersion) -> some View {
        let name = address.description
        let api = version.api.description
        let text: LocalizedStringKey =
            version.api.compatibility == .hostNewer
            ? "\(name) speaks API \(api), newer than this app supports. Update the app."
            : "\(name) speaks API \(api), older than this app supports. Update the host."
        return Label(text, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
    }

    private func failed(_ address: HostAddress, _ failure: HostFailure) -> some View {
        let name = address.description
        let endpoint = "\(address.host):\(address.port)"
        let text: LocalizedStringKey =
            switch failure {
            case .unreachable:
                """
                Couldn't reach \(name). Check the address and that the host is on. The app also \
                needs Local Network access, in System Settings > Privacy & Security.
                """
            case .refused:
                "\(name) refused the request."
            case .unexpectedAnswer:
                "Something answered at \(endpoint), but not an audio-vue host."
            case .tokenRefused, .pairingRefused, .unknownClient:
                "\(name) answered in a way this app didn't expect."
            }
        return Label(text, systemImage: "xmark.octagon.fill")
    }
}

/// Whether this Mac is paired with the connected host, and the way to pair or to its clients.
struct PairingSection: View {
    let paired: Bool
    let actions: ConnectionActions

    var body: some View {
        if paired {
            Label("This Mac is paired with the host.", systemImage: "link")
            Button("Show Clients…", action: actions.showClients)
        } else {
            Label(
                "This Mac isn't paired. Pairing takes the code the host's panel shows.",
                systemImage: "link.badge.plus")
            Button("Pair with This Host…", action: actions.pair)
                .keyboardShortcut(.defaultAction)
        }
    }
}

#Preview("Idle") {
    ConnectForm(address: .constant("audio-vue"), state: .idle)
}

#Preview("Connected, paired") {
    if let address = HostAddress(parsing: "audio-vue"), let api = APIVersion(parsing: "2.0.0") {
        ConnectForm(
            address: .constant("audio-vue"),
            state: .connected(address, HostVersion(api: api, schema: 1), paired: true))
    }
}

#Preview("Connected, not paired") {
    if let address = HostAddress(parsing: "audio-vue"), let api = APIVersion(parsing: "2.0.0") {
        ConnectForm(
            address: .constant("audio-vue"),
            state: .connected(address, HostVersion(api: api, schema: 1), paired: false))
    }
}

#Preview("Failed") {
    if let address = HostAddress(parsing: "audio-vue") {
        ConnectForm(address: .constant("audio-vue"), state: .failed(address, .unreachable))
    }
}
