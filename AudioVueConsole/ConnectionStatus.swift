import ConsoleCore
import SwiftUI

/// Whether a paired host is sending its state: so connected is said only while it is.
enum HostContact {
    case live
    /// Paired, and no state heard yet.
    case waiting
    /// Paired, and the state stopped coming; `LiveState` is trying again.
    case lost

    init(_ live: LiveState?) {
        if live?.isLive == true {
            self = .live
        } else {
            self = live?.state == nil ? .waiting : .lost
        }
    }
}

/// What a connection came to, in words: connected only when paired and the host is sending its
/// state, since only then can the panel be used (discovery design D10). The panel goes by `name`,
/// the picker's, where one is given; a failure names the address, since it is about reaching it.
struct ConnectionStatus: View {
    var name: String?
    /// For a paired host, whether it is sending its state.
    var contact = HostContact.live
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
                Text("Connecting to \(name ?? address.description)…")
            } icon: {
                ProgressView().controlSize(.small)
            }
        case .connected(let address, let version, let paired):
            connected(name ?? address.description, version, paired: paired)
        case .incompatible(let address, let version):
            incompatible(address, version)
        case .failed(let address, let failure):
            failed(address, failure).foregroundStyle(.red)
        case .unresolved(let name, let failure):
            unresolved(name, failure).foregroundStyle(.red)
        }
    }

    /// Connected, green, when paired and live; else only what the host says of itself, since a
    /// host that answers but is not paired cannot be used yet.
    @ViewBuilder
    private func connected(_ name: String, _ version: HostVersion, paired: Bool) -> some View {
        if paired { contactLine(name) }
        LabeledContent("API version") { Text(verbatim: version.api.description) }
        LabeledContent("State schema") {
            if let schema = version.schema {
                Text(verbatim: "\(schema)")
            } else {
                Text("Panel not answering")
            }
        }
    }

    @ViewBuilder
    private func contactLine(_ name: String) -> some View {
        switch contact {
        case .live:
            Label("Connected to \(name)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .waiting:
            Label {
                Text("Connecting to \(name)…")
            } icon: {
                ProgressView().controlSize(.small)
            }
        case .lost:
            Label(
                "Lost contact with \(name). Trying again…",
                systemImage: "antenna.radiowaves.left.and.right.slash"
            )
            .foregroundStyle(.orange)
        }
    }

    /// A host at another API version than the saved contract's, the one this app speaks
    /// (`host-connection`), with the step that brings them level (design D2).
    private func incompatible(_ address: HostAddress, _ version: HostVersion) -> some View {
        let name = name ?? address.description
        let theirs = version.api.description
        let ours = SavedContract.bundled.version.description
        let text: LocalizedStringKey =
            version.api.compatibility == .hostNewer
            ? """
            \(name) runs host API \(theirs), newer than this app's \(ours). Refresh this app's \
            contract and build again.
            """
            : """
            \(name) runs host API \(theirs), older than this app's \(ours). Deploy audio-vue to \
            the panel.
            """
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
            case .tokenRefused, .pairingRefused, .unknownClient, .notFound, .stale, .invalid,
                .conflict:
                "\(name) answered in a way this app didn't expect."
            }
        return Label(text, systemImage: "xmark.octagon.fill")
    }

    /// A found panel whose announcement gave no address the app can reach.
    private func unresolved(_ name: String, _ failure: HostFailure) -> some View {
        let text: LocalizedStringKey =
            failure == .unexpectedAnswer
            ? "\(name) is announced at a name that isn't a host address."
            : "Couldn't find where \(name) is on the network. Check that the host is on."
        return Label(text, systemImage: "xmark.octagon.fill")
    }
}

#Preview("A host older than the app") {
    RefusedHostPreview(api: "1.0.0").frame(width: 520, alignment: .leading)
}

#Preview("A host newer than the app") {
    RefusedHostPreview(api: "99.0.0").frame(width: 520, alignment: .leading)
}

/// The status for a host at `api`, refused on connect.
private struct RefusedHostPreview: View {
    let api: String

    var body: some View {
        if let address = HostAddress(parsing: "audio-vue.local"),
            let version = APIVersion(parsing: api)
        {
            ConnectionStatus(
                name: "audio-vue",
                state: .incompatible(address, HostVersion(api: version, schema: 1, cards: .preview))
            )
            .padding()
        }
    }
}
