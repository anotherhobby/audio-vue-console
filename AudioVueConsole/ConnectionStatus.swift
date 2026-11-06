import ConsoleCore
import SwiftUI

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
