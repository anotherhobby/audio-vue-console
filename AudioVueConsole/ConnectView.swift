import ConsoleCore
import SwiftUI

/// Connecting to one host by the address the user gives, and what came of it. The model does the
/// work; this only shows it.
struct ConnectView: View {
    @State private var connection = HostConnection()

    var body: some View {
        ConnectForm(address: $connection.addressText, state: connection.state) {
            Task { await connection.connect() }
        }
    }
}

/// The connect form for a given state, so previews can show each one.
struct ConnectForm: View {
    @Binding var address: String
    let state: HostConnection.State
    let connect: () -> Void

    private static let minWidth: CGFloat = 440
    private static let minHeight: CGFloat = 300

    var body: some View {
        Form {
            Section {
                TextField("Address", text: $address, prompt: Text(verbatim: "audio-vue.local"))
                    .onSubmit(connect)
                    .disabled(isConnecting)
            } footer: {
                Text("A hostname or IPv4 address, with a port if it isn't 19200.")
            }
            Section {
                ConnectionStatus(state: state)
            }
            Section {
                Button("Connect", action: connect)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isConnecting || address.isEmpty)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: Self.minWidth, minHeight: Self.minHeight)
    }

    private var isConnecting: Bool {
        if case .connecting = state { return true }
        return false
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
        case .connected(let address, let version):
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
            }
        return Label(text, systemImage: "xmark.octagon.fill")
    }
}

#Preview("Idle") {
    ConnectForm(address: .constant("audio-vue"), state: .idle) {}
}

#Preview("Connected") {
    if let address = HostAddress(parsing: "audio-vue"), let api = APIVersion(parsing: "1.0.0") {
        ConnectForm(
            address: .constant("audio-vue"),
            state: .connected(address, HostVersion(api: api, schema: 1))
        ) {}
    }
}

#Preview("Failed") {
    if let address = HostAddress(parsing: "audio-vue") {
        ConnectForm(address: .constant("audio-vue"), state: .failed(address, .unreachable)) {}
    }
}
